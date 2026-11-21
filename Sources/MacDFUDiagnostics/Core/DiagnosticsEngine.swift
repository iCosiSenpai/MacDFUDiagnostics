import AppKit
import CHPMBridge
import Foundation
import Observation
import UniformTypeIdentifiers

/// Everything the hardware scan learns in one pass. Built off the main thread, applied on it.
struct HardwareSnapshot: Sendable {
    var ports: [HostPort] = []
    var devices: [TargetDevice] = []
    var consoles: [String] = []
}

/// The app's model of the hardware and of whatever it is currently doing to it.
@MainActor
@Observable
final class DiagnosticsEngine {
    // Host
    private(set) var host = HostInfo()
    private(set) var ports: [HostPort] = []
    var selectedPortRID: Int32 = 0

    // Connected hardware
    private(set) var devices: [TargetDevice] = []
    var focusedDeviceID: TargetDevice.ID?
    private(set) var serialConsoles: [String] = []
    private(set) var disks: [ExternalDisk] = []
    private(set) var hasLoadedDisks = false
    private(set) var diskChecks: [ExternalDisk.ID: DiskCheck] = [:]
    private(set) var bridge: BridgeState = .absent

    // Work in progress and its trail
    private(set) var operation: Operation?
    private(set) var log: [LogEntry] = []
    private(set) var notice: Notice?
    /// Goes up each time a Mac that can take firmware appears. The interface reacts to the change.
    private(set) var arrivals = 0
    /// Goes up each time an action ends well.
    private(set) var successes = 0

    /// A firmware file the user picked for the next restore. `nil` means "get the latest from Apple".
    var firmwareURL: URL?

    @ObservationIgnored private var watcher: HardwareWatcher?
    @ObservationIgnored private var isScanning = false
    @ObservationIgnored private var scanRequested = false
    @ObservationIgnored private var usbDebounce: Task<Void, Never>?
    @ObservationIgnored private var diskDebounce: Task<Void, Never>?
    @ObservationIgnored private var firmwareReadyIDs: Set<TargetDevice.ID> = []
    @ObservationIgnored private var connectedRIDs: Set<Int32> = []
    @ObservationIgnored private var activeProcess: StreamingProcess?
    @ObservationIgnored private var stopRequested = false

    /// Called when an operation worth remembering ends: the history keeps it, and a notification
    /// says so if the app is not in front.
    @ObservationIgnored var onFinish: ((OperationRecord) -> Void)?

    /// Set when the app was launched with `-demo`: the hardware is simulated and nothing real is touched.
    let demo: DemoScenario?

    private static let logLimit = 400

    init(demo: DemoScenario? = nil) {
        self.demo = demo
        host = Self.readHost()
    }

    var isBusy: Bool { operation != nil }

    /// The device the main window is about: the one the user picked, else the one ready for firmware,
    /// else the only one there is.
    var focusedDevice: TargetDevice? {
        devices.first { $0.id == focusedDeviceID }
            ?? devices.first { $0.state.acceptsFirmware }
            ?? devices.first
    }

    var selectedPort: HostPort? {
        ports.first { $0.rid == selectedPortRID }
    }

    // MARK: - Watching the hardware

    /// Starts listening for plug and unplug events. Called once, for the life of the app.
    func start() {
        if let demo {
            startDemo(demo)
            return
        }
        guard watcher == nil else { return }
        watcher = HardwareWatcher { [weak self] change in
            Task { @MainActor in self?.hardwareChanged(change) }
        }
        refreshHardware()
    }

    private func hardwareChanged(_ change: HardwareWatcher.Change) {
        switch change {
        case .usb:
            // A Mac changing mode detaches and re-attaches within milliseconds; scan once it settles.
            usbDebounce?.cancel()
            usbDebounce = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self?.refreshHardware()
            }
        case .disk:
            guard hasLoadedDisks else { return }
            diskDebounce?.cancel()
            diskDebounce = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                await self?.refreshDisks()
            }
        }
    }

    /// Rescans ports and USB devices. The scan walks the I/O Registry, so it runs off the main thread;
    /// requests that arrive while one is running are folded into a single follow-up.
    func refreshHardware() {
        guard demo == nil else { return }
        guard !isScanning else {
            scanRequested = true
            return
        }
        isScanning = true
        Task {
            repeat {
                scanRequested = false
                let snapshot = await Task.detached(priority: .userInitiated) { Self.scan() }.value
                apply(snapshot)
            } while scanRequested
            isScanning = false
        }
    }

    private func apply(_ snapshot: HardwareSnapshot) {
        if ports != snapshot.ports {
            ports = snapshot.ports
            if !ports.contains(where: { $0.rid == selectedPortRID }),
               let fallback = ports.first(where: \.isDFUCapable) ?? ports.first {
                selectedPortRID = fallback.rid
            }
        }
        if serialConsoles != snapshot.consoles {
            serialConsoles = snapshot.consoles
        }

        let ready = Set(snapshot.devices.filter { $0.state.acceptsFirmware }.map(\.id))
        if let arrived = snapshot.devices.first(where: { ready.subtracting(firmwareReadyIDs).contains($0.id) }) {
            arrivals += 1
            record(.success, "\(arrived.title) is ready in DFU.", detail: arrived.ecid.map { "ECID \($0)" })
        }
        firmwareReadyIDs = ready

        // Follow the cable: when a Mac shows up on another port, that is the port to talk to. A port the
        // user picked by hand stays picked until the set of occupied ports changes again.
        let occupied = Set(snapshot.devices.compactMap(\.hostPortRID))
        if occupied != connectedRIDs {
            connectedRIDs = occupied
            let preferred = snapshot.devices.first { $0.state.acceptsFirmware && $0.hostPortRID != nil } ?? snapshot.devices.first { $0.hostPortRID != nil }
            if let rid = preferred?.hostPortRID, rid != selectedPortRID {
                selectedPortRID = rid
            }
        }

        if devices != snapshot.devices {
            devices = snapshot.devices
            if let focusedDeviceID, !devices.contains(where: { $0.id == focusedDeviceID }) {
                self.focusedDeviceID = nil
            }
        }
    }

    // MARK: - Scanning (off the main thread)

    private nonisolated static func readHost() -> HostInfo {
        var info = HostInfo()
        #if arch(arm64)
        info.isAppleSilicon = true
        #endif

        var name = [CChar](repeating: 0, count: 64)
        var key: UInt32 = 0
        if hpm_get_host_platform(&name, name.count, &key) {
            info.board = String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            info.model = MacCatalog.model(board: info.board)
        }
        return info
    }

    nonisolated static func scan() -> HardwareSnapshot {
        var snapshot = HardwareSnapshot()

        var rawPorts = [HPMHostPortInfo](repeating: HPMHostPortInfo(), count: 16)
        let portCount = hpm_list_host_ports(&rawPorts, rawPorts.count)
        snapshot.ports = rawPorts.prefix(portCount).map { raw in
            HostPort(
                rid: raw.rid,
                portNumber: raw.port_number,
                locationBase: raw.location_base,
                isDFUCapable: raw.is_dfu_capable,
                name: text(raw.location_name)
            )
        }
        .sorted { $0.rid < $1.rid }

        if let entries = try? FileManager.default.contentsOfDirectory(atPath: "/dev") {
            snapshot.consoles = entries
                .filter { $0.hasPrefix("cu.debug") || $0.hasPrefix("cu.kis-") }
                .map { "/dev/\($0)" }
                .filter(isValidConsolePath)
                .sorted()
        }

        var rawDevices = [HPMUSBDeviceInfo](repeating: HPMUSBDeviceInfo(), count: 32)
        let deviceCount = hpm_list_apple_usb_devices(&rawDevices, rawDevices.count)
        snapshot.devices = rawDevices.prefix(deviceCount).compactMap { device(from: $0, ports: snapshot.ports) }

        return snapshot
    }

    private nonisolated static func device(from raw: HPMUSBDeviceInfo, ports: [HostPort]) -> TargetDevice? {
        let productName = text(raw.product_name)
        let serial = text(raw.serial_number)
        let state = TargetState.from(productID: raw.product_id, productName: productName, serial: serial)

        // Keyboards, displays and iPhones are Apple USB devices too; only Macs (or what looks like one
        // in a low-level mode) belong here.
        let looksLikeTarget = state != .other
            || serial.contains("CPID:")
            || ["DFU", "Recovery", "Apple Mobile Device", "Mac"].contains { productName.localizedCaseInsensitiveContains($0) }
        guard looksLikeTarget else { return nil }

        let identity = DeviceIdentity.parse(serial: serial, isPortDFU: state == .portDFU)
        var model: MacModel?
        if let cpid = identity.cpid, let bdid = identity.bdid {
            model = MacCatalog.model(cpid: cpid, bdid: bdid)
        } else if state == .booted {
            model = MacCatalog.model(bootedBCDDevice: raw.bcd_device, productName: productName)
        }

        // A running Mac reports its serial number as the USB serial — unless that string turned out to
        // be the chip-and-ECID pair, which was already used above.
        var serialNumber = identity.serialNumber
        if serialNumber == nil, state == .booted, identity.ecid == nil, !serial.isEmpty {
            serialNumber = serial
        }

        let locationBase = raw.location_id & 0xFF00_0000
        let port = ports.first { $0.locationBase != 0 && $0.locationBase == locationBase }
        let usbID = String(format: "%04x:%04x", raw.vendor_id, raw.product_id)

        return TargetDevice(
            id: "\(usbID)-\(raw.location_id)-\(identity.ecid ?? serial)",
            vendorID: raw.vendor_id,
            productID: raw.product_id,
            bcdDevice: raw.bcd_device,
            locationID: raw.location_id,
            productName: productName,
            rawSerial: serial,
            state: state,
            cpid: identity.cpid ?? model?.cpid,
            bdid: identity.bdid ?? model?.bdid,
            ecid: identity.ecid,
            iBootTag: identity.iBootTag,
            serialNumber: serialNumber,
            model: model,
            hostPortRID: port?.rid
        )
    }

    /// Reads a fixed-size C `char` array as text, stopping at the first NUL or at the end of the array.
    private nonisolated static func text<T>(_ field: T) -> String {
        withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    // MARK: - USB-C vendor messages

    /// Sends one vendor message through the selected host port. Asks for an administrator password.
    func send(_ command: VDMCommand) async {
        guard operation == nil else { return }
        guard host.isAppleSilicon else {
            report(.failure, "This needs an Apple silicon Mac as the host.")
            return
        }

        operation = Operation(kind: .vdm(command))
        defer { operation = nil }

        if demo != nil {
            await simulate(command)
            return
        }

        let rid = selectedPortRID
        let started = Date()
        let target = focusedDevice
        let outcome = await PrivilegedHelper.run(
            command,
            rid: rid,
            prompt: String(localized: "Mac DFU Studio needs to talk to the USB-C port controller.")
        )

        switch outcome {
        case .reply(let reply):
            let detail = "\(reply.message) [RID \(reply.usedRID), reply \(reply.vdmReplyHeaderHex)]"
            if reply.statusCode == 0 {
                successes += 1
                report(.success, Self.successMessage(for: command, reply: reply), detail: detail)
            } else {
                report(.failure, Self.failureMessage(forStatus: reply.statusCode), detail: detail)
            }
            finished(command, succeeded: reply.statusCode == 0, on: target, since: started, detail: reply.message)
        case .cancelled:
            record(.info, "Cancelled.")
        case .refused:
            report(.failure, "The helper tool is missing or damaged. Reinstall the app.")
        case .failed(let output):
            report(.failure, "The request couldn't be sent.", detail: output)
        }

        // The target needs a moment to drop off the bus and come back in its new mode.
        try? await Task.sleep(for: .seconds(1.2))
        refreshHardware()
    }

    /// Hands a finished cable command to whoever keeps the history. Only the two that change the
    /// state of the other Mac are worth a line there.
    private func finished(_ command: VDMCommand, succeeded: Bool, on device: TargetDevice?, since started: Date, detail: String?) {
        let kind: OperationRecord.Kind
        switch command {
        case .dfu, .dfuSilicon, .dfuT2: kind = .enterDFU
        case .restart: kind = .restart
        case .serial, .debugUSB, .probe: return
        }
        onFinish?(OperationRecord(
            kind: kind, outcome: succeeded ? .success : .failure,
            device: device?.title ?? "Mac", ecid: device?.ecid,
            duration: Date().timeIntervalSince(started), detail: detail
        ))
    }

    private func finished(_ kind: Operation.Kind, outcome: OperationRecord.Outcome, on device: TargetDevice?, since started: Date, detail: String?) {
        onFinish?(OperationRecord(
            kind: kind == .restore ? .restore : .revive, outcome: outcome,
            device: device?.title ?? "Mac", ecid: device?.ecid,
            duration: Date().timeIntervalSince(started), detail: detail
        ))
    }

    private static func successMessage(for command: VDMCommand, reply: PrivilegedHelper.Reply) -> LocalizedStringResource {
        switch command {
        case .dfu, .dfuSilicon, .dfuT2: "The Mac is entering DFU."
        case .restart: "The Mac is restarting."
        case .serial: "Serial console is ready."
        case .debugUSB: "Debug USB is on."
        case .probe: reply.connected ? "The port works and something is connected." : "The port works. Nothing is connected."
        }
    }

    private static func failureMessage(forStatus status: Int) -> LocalizedStringResource {
        switch status {
        case -2: "Administrator access is required."
        case -3, -4, -5: "This port couldn't be opened."
        case -6: "No Mac is connected to this port."
        case -7, -8: "The port controller refused the request."
        case -9: "The Mac didn't accept the DFU request."
        case -10: "The Mac didn't restart."
        case -11: "The serial console couldn't be started."
        case -12: "Debug USB couldn't be turned on."
        default: "Something went wrong."
        }
    }

    // MARK: - Revive and restore

    static let configuratorURL = URL(string: "https://apps.apple.com/app/apple-configurator/id1037126344")!

    /// Where Apple Configurator keeps `cfgutil` (or links it, after "Install Automation Tools").
    var cfgutilPath: String? {
        if demo != nil { return "/usr/bin/true" }
        return [
            "/Applications/Apple Configurator.app/Contents/MacOS/cfgutil",
            "/Applications/Apple Configurator 2.app/Contents/MacOS/cfgutil",
            "/usr/local/bin/cfgutil",
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func revive(_ device: TargetDevice) async {
        await runFirmware(.revive, on: device)
    }

    func restore(_ device: TargetDevice) async {
        await runFirmware(.restore, on: device)
    }

    /// Stops a running revive or restore.
    func stopOperation() {
        guard operation?.canStop == true else { return }
        stopRequested = true
        activeProcess?.stop()
    }

    private func runFirmware(_ kind: Operation.Kind, on device: TargetDevice) async {
        guard operation == nil else { return }
        if demo != nil {
            await simulateFirmware(kind)
            return
        }
        guard let cfgutil = cfgutilPath else {
            report(.failure, "Apple Configurator is needed. Install it from the App Store.")
            return
        }

        var arguments = ["--progress"]
        if let ecid = device.ecid {
            arguments += ["--ecid", ecid]
        }

        if kind == .restore {
            arguments.append("restore")
            // A T2 restores bridgeOS, which Configurator fetches itself; a Mac firmware file is no use to it.
            if !device.isIntelT2, let firmware = firmwareURL {
                guard Self.isFirmwareFile(firmware) else {
                    report(.failure, "The firmware file can't be read.")
                    return
                }
                if let shortfall = Self.diskSpaceShortfall(forUnpacking: firmware) {
                    let amount = ByteCountFormatter.string(fromByteCount: shortfall, countStyle: .file)
                    report(.failure, "Not enough disk space. Free up \(amount) and try again.")
                    return
                }
                arguments += ["-I", firmware.path(percentEncoded: false)]
            }
        } else {
            arguments.append("revive")
        }

        operation = Operation(kind: kind, progress: nil)
        stopRequested = false
        let started = Date()
        record(.info, kind == .restore ? "Restore started." : "Revive started.", detail: "cfgutil " + arguments.joined(separator: " "))

        // Sleeping in the middle of a firmware write is the one thing that must not happen.
        let awake = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Reviving or restoring a Mac"
        )

        let process = StreamingProcess()
        activeProcess = process
        let (lines, feed) = AsyncStream<String>.makeStream()
        let reader = Task { [weak self] in
            var lastStep = ""
            for await line in lines {
                self?.consumeToolLine(line, lastStep: &lastStep)
            }
        }

        let status = await process.run(cfgutil, arguments) { feed.yield($0) }
        feed.finish()
        await reader.value

        ProcessInfo.processInfo.endActivity(awake)
        activeProcess = nil
        operation = nil

        finished(kind, outcome: stopRequested ? .stopped : (status == 0 ? .success : .failure), on: device, since: started,
                 detail: status == 0 || stopRequested ? nil : "cfgutil exit \(status)")

        if stopRequested {
            report(.warning, "Stopped.")
        } else if status == 0 {
            successes += 1
            if kind == .restore, device.isIntelT2 {
                report(.success, "Restore complete. The Mac starts macOS Recovery over the internet: install macOS from there.")
            } else {
                report(.success, kind == .restore ? "Restore complete." : "Revive complete.")
            }
        } else {
            report(.failure, kind == .restore ? "Restore failed." : "Revive failed.", detail: "cfgutil exit \(status)")
        }
        refreshHardware()
    }

    /// Turns one line of tool output into progress, a status line and — when the step changes — a log entry.
    private func consumeToolLine(_ raw: String, lastStep: inout String) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.hasPrefix("{"), !line.hasPrefix("}") else { return }

        if let match = line.matches(of: /(\d{1,3}(?:\.\d+)?)\s*%/).last, let percent = Double(match.1), percent <= 100 {
            operation?.progress = percent / 100
        }
        operation?.detail = String(line.prefix(120))

        // Progress ticks repeat the same step hundreds of times; log a step once.
        let step = line.replacing(/[\d.]+\s*%?/, with: "").trimmingCharacters(in: .whitespaces)
        if step != lastStep, !step.isEmpty {
            lastStep = step
            record(.info, "Configurator", detail: line)
        }
    }

    nonisolated static func isFirmwareFile(_ url: URL) -> Bool {
        url.isFileURL
            && url.pathExtension.lowercased() == "ipsw"
            && FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false))
    }

    /// How many bytes are missing to unpack a firmware file, or `nil` when there is room.
    private nonisolated static func diskSpaceShortfall(forUnpacking firmware: URL) -> Int64? {
        guard let size = (try? firmware.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
              let values = try? URL.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let available = values.volumeAvailableCapacityForImportantUsage, available > 0 else { return nil }
        let needed = Int64(size) + 2 * 1_073_741_824
        return available < needed ? needed - available : nil
    }

    // MARK: - Disks (Target Disk Mode)

    func refreshDisks() async {
        if demo != nil {
            disks = DemoScenario.disks
            bridge = .active
            hasLoadedDisks = true
            return
        }
        async let bridgeState = Self.readBridge()
        let found = await Self.readDisks()
        disks = found
        bridge = await bridgeState
        hasLoadedDisks = true
        diskChecks = diskChecks.filter { check in found.contains { $0.id == check.key } }
    }

    private nonisolated static func readDisks() async -> [ExternalDisk] {
        let listing = await ProcessRunner.run("/usr/sbin/diskutil", ["list", "-plist", "external"])
        guard let root = plist(listing.output),
              let whole = root["WholeDisks"] as? [String] else { return [] }
        let layout = (root["AllDisksAndPartitions"] as? [[String: Any]]) ?? []

        // APFS volumes live in a synthesized container disk (disk5) whose physical store is a partition
        // of the real disk (disk4s2). Collect each container's volumes under the disk that stores it.
        var volumesByDisk: [String: [DiskVolume]] = [:]
        var containers: Set<String> = []
        for entry in layout {
            guard let identifier = entry["DeviceIdentifier"] as? String else { continue }
            let stores = (entry["APFSPhysicalStores"] as? [[String: Any]] ?? []).compactMap { $0["DeviceIdentifier"] as? String }
            let owner: String
            if let store = stores.first, let match = store.firstMatch(of: /^(disk[0-9]+)s[0-9]+/) {
                containers.insert(identifier)
                owner = String(match.1)
            } else {
                owner = identifier
            }
            let parts = (entry["Partitions"] as? [[String: Any]] ?? []) + (entry["APFSVolumes"] as? [[String: Any]] ?? [])
            volumesByDisk[owner, default: []] += parts.compactMap { part in
                guard let id = part["DeviceIdentifier"] as? String,
                      let name = part["VolumeName"] as? String, !name.isEmpty else { return nil }
                return DiskVolume(id: id, name: name, mountPoint: part["MountPoint"] as? String)
            }
        }

        var disks: [ExternalDisk] = []
        for identifier in whole where ExternalDisk.isValidIdentifier(identifier) && !containers.contains(identifier) {
            let result = await ProcessRunner.run("/usr/sbin/diskutil", ["info", "-plist", identifier])
            guard let info = plist(result.output) else { continue }
            // Mounted disk images (simulator runtimes, toolchains) are "external" too, and are not disks.
            let bus = (info["BusProtocol"] as? String) ?? ""
            guard bus != "Disk Image" else { continue }

            let smart = info["SMARTStatus"] as? String
            disks.append(ExternalDisk(
                id: identifier,
                name: (info["MediaName"] as? String) ?? identifier,
                sizeBytes: (info["TotalSize"] as? NSNumber)?.int64Value ?? 0,
                bus: bus,
                smartStatus: smart == "Not Supported" ? nil : smart,
                volumes: volumesByDisk[identifier] ?? []
            ))
        }
        return disks
    }

    private nonisolated static func plist(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private nonisolated static func readBridge() async -> BridgeState {
        let result = await ProcessRunner.run("/sbin/ifconfig", ["bridge0"])
        guard result.succeeded, !result.output.isEmpty else { return .absent }
        return result.output.contains("status: active") ? .active : .inactive
    }

    /// Checks a disk's partition map and file systems. Read-only: nothing is repaired.
    func check(_ disk: ExternalDisk) async {
        guard ExternalDisk.isValidIdentifier(disk.id), diskChecks[disk.id]?.outcome != .running else { return }
        diskChecks[disk.id] = DiskCheck(outcome: .running, output: "")

        if demo != nil {
            try? await Task.sleep(for: .seconds(1.5))
            diskChecks[disk.id] = DiskCheck(outcome: .passed, output: "Started partition map verification on \(disk.id)\nThe partition map appears to be OK")
            return
        }

        let result = await ProcessRunner.run("/usr/sbin/diskutil", ["verifyDisk", disk.id])
        diskChecks[disk.id] = DiskCheck(outcome: result.succeeded ? .passed : .problems, output: result.output)
        if result.succeeded {
            record(.success, "\(disk.name) passed its check.")
        } else {
            record(.warning, "\(disk.name) has problems.", detail: "diskutil exit \(result.status)")
        }
    }

    /// Ejects every volume of a disk, so the cable can be pulled safely.
    func eject(_ disk: ExternalDisk) async {
        guard ExternalDisk.isValidIdentifier(disk.id) else { return }
        if demo != nil {
            disks.removeAll { $0.id == disk.id }
            report(.success, "\(disk.name) ejected. It is safe to disconnect.")
            return
        }
        let result = await ProcessRunner.run("/usr/sbin/diskutil", ["eject", disk.id])
        if result.succeeded {
            report(.success, "\(disk.name) ejected. It is safe to disconnect.")
        } else {
            report(.failure, "\(disk.name) couldn't be ejected. Close the files that are in use and try again.", detail: result.output)
        }
        await refreshDisks()
    }

    /// Shows a mounted volume in the Finder.
    func reveal(_ volume: DiskVolume) {
        guard let mountPoint = volume.mountPoint else { return }
        NSWorkspace.shared.open(URL(filePath: mountPoint, directoryHint: .isDirectory))
    }

    enum SystemTool {
        case migrationAssistant
        case diskUtility
        /// The Finder's Network window, where a Mac sharing its disk appears.
        case network

        var url: URL {
            switch self {
            case .migrationAssistant: URL(filePath: "/System/Applications/Utilities/Migration Assistant.app")
            case .diskUtility: URL(filePath: "/System/Applications/Utilities/Disk Utility.app")
            case .network: URL(filePath: "/System/Library/CoreServices/Finder.app/Contents/Applications/Network.app")
            }
        }
    }

    func open(_ tool: SystemTool) {
        NSWorkspace.shared.open(tool.url)
    }

    // MARK: - Serial console

    /// Console device nodes are named by the system; anything else is not passed to a shell.
    nonisolated static func isValidConsolePath(_ path: String) -> Bool {
        path.wholeMatch(of: /\/dev\/cu\.[A-Za-z0-9._-]{1,64}/) != nil
    }

    static let baudRates = [9_600, 57_600, 115_200, 230_400, 921_600]

    /// Opens the console in Terminal by handing it a tiny script file — no Apple events, so no
    /// Automation permission prompt and nothing built by string-pasting into AppleScript.
    func openSerialConsole(_ path: String, baudRate: Int) {
        guard Self.isValidConsolePath(path), Self.baudRates.contains(baudRate) else {
            report(.failure, "That serial port can't be opened.")
            return
        }
        do {
            let folder = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: CodeTrust.appIdentifier, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let script = folder.appending(path: "Serial Console.command")
            let body = "#!/bin/sh\nexec /usr/bin/screen \(ProcessRunner.shellQuoted(path)) \(baudRate)\n"
            try body.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
            NSWorkspace.shared.open(script)
            record(.info, "Serial console opened in Terminal.", detail: "screen \(path) \(baudRate)")
        } catch {
            report(.failure, "The serial console couldn't be opened.", detail: error.localizedDescription)
        }
    }

    // MARK: - Activity

    /// Adds a line to the activity log.
    func record(_ level: LogLevel, _ message: LocalizedStringResource, detail: String? = nil) {
        log.append(LogEntry(level: level, message: message, detail: detail))
        if log.count > Self.logLimit {
            log.removeFirst(log.count - Self.logLimit)
        }
    }

    /// Logs a line and also shows it in the window for a few seconds.
    func report(_ level: LogLevel, _ message: LocalizedStringResource, detail: String? = nil) {
        record(level, message, detail: detail)
        let shown = Notice(level: level, message: message)
        notice = shown
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(level == .failure ? 9 : 5))
            if self?.notice?.id == shown.id { self?.notice = nil }
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func clearLog() {
        log.removeAll()
    }

    /// A plain-text report for a support ticket. Always in English: it is read by technicians and tools.
    func diagnosticReport() -> String {
        var lines: [String] = []
        lines.append("Mac DFU Studio — diagnostic report")
        lines.append("Date: \(Date().formatted(.iso8601))")
        lines.append("Host: \(host.name) [\(host.board)]")
        lines.append("cfgutil: \(cfgutilPath ?? "not installed")")
        lines.append("")
        lines.append("Host ports (\(ports.count))")
        for port in ports {
            lines.append("  RID \(port.rid)  \(port.name)  USB base \(String(format: "0x%08X", port.locationBase))  DFU: \(port.isDFUCapable ? "yes" : "no")")
        }
        lines.append("")
        lines.append("Devices (\(devices.count))")
        for device in devices {
            lines.append("  \(device.title) — \(device.state.rawValue)")
            lines.append("    USB \(device.usbID)  location \(String(format: "0x%08X", device.locationID))  port RID \(device.hostPortRID.map(String.init) ?? "-")")
            lines.append("    CPID \(device.cpid.map { String(format: "0x%04X", $0) } ?? "-")  BDID \(device.bdid.map { String(format: "0x%02X", $0) } ?? "-")  ECID \(device.ecid ?? "-")  iBoot \(device.iBootTag ?? "-")")
        }
        lines.append("")
        lines.append("External disks (\(disks.count))")
        for disk in disks {
            lines.append("  /dev/\(disk.id)  \(disk.name)  \(disk.formattedSize)  \(disk.bus)  SMART: \(disk.smartStatus ?? "n/a")")
        }
        lines.append("")
        lines.append("Activity (\(log.count))")
        let english = Locale(identifier: "en")
        for entry in log {
            var message = entry.message
            message.locale = english
            let detail = entry.detail.map { " — \($0)" } ?? ""
            lines.append("  [\(entry.level.rawValue)] \(String(localized: message))\(detail)")
        }
        return lines.joined(separator: "\n")
    }

    /// Writes the report to a file the user chooses: easier to attach to a ticket than a clipboard.
    func saveDiagnosticReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Mac DFU Studio report \(Date().formatted(.iso8601.year().month().day())).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try diagnosticReport().write(to: url, atomically: true, encoding: .utf8)
            report(.success, "Report saved.")
        } catch {
            report(.failure, "The report couldn't be saved.", detail: error.localizedDescription)
        }
    }

    func copyDiagnosticReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticReport(), forType: .string)
        report(.success, "Report copied.")
    }

    // MARK: - Demo

    private func startDemo(_ scenario: DemoScenario) {
        ports = [
            HostPort(rid: 0, portNumber: 1, locationBase: 0x0100_0000, isDFUCapable: true, name: "left-front"),
            HostPort(rid: 1, portNumber: 2, locationBase: 0x0200_0000, isDFUCapable: false, name: "left-back"),
        ]
        devices = scenario.devices
        if !devices.isEmpty { arrivals += 1 }
        record(.info, "Demo: simulated hardware. Nothing real is touched.")
        if scenario == .restoring, let device = devices.first {
            Task { await restore(device) }
        }
        if scenario == .tour {
            Task { await playTour() }
        }
    }

    /// The scripted demo: nothing → a running Mac → DFU → revive → done.
    private func playTour() async {
        try? await Task.sleep(for: .seconds(2.2))
        devices = DemoScenario.booted.devices
        try? await Task.sleep(for: .seconds(2.4))
        await send(.dfu)
        try? await Task.sleep(for: .seconds(2.4))
        if let device = focusedDevice {
            await revive(device)
        }
    }

    private func simulate(_ command: VDMCommand) async {
        try? await Task.sleep(for: .seconds(1.4))
        let reply = PrivilegedHelper.Reply(
            statusCode: 0, usedRID: 0, connected: true, usedT2Fallback: false,
            vdmReplyHeaderHex: "0x05AC8052", hpmStatus: "DBMa", message: "Simulated."
        )
        successes += 1
        report(.success, Self.successMessage(for: command, reply: reply), detail: "Simulated")
        finished(command, succeeded: true, on: focusedDevice, since: Date().addingTimeInterval(-1.4), detail: "Simulated")
        switch command {
        case .dfu, .dfuSilicon, .dfuT2:
            devices = DemoScenario.dfu.devices
            arrivals += 1
        case .restart:
            devices = DemoScenario.booted.devices
        default:
            break
        }
    }

    private func simulateFirmware(_ kind: Operation.Kind) async {
        operation = Operation(kind: kind, progress: 0)
        stopRequested = false
        let started = Date()
        let target = focusedDevice
        record(.info, kind == .restore ? "Restore started." : "Revive started.", detail: "Simulated")

        let steps = ["Downloading firmware", "Verifying", "Preparing the Mac", "Installing", "Finishing"]
        var fraction = 0.0
        while fraction < 1, !stopRequested {
            try? await Task.sleep(for: .milliseconds(140))
            fraction = min(1, fraction + (demo == .tour ? 0.024 : 0.012))
            operation?.progress = fraction
            operation?.detail = steps[min(steps.count - 1, Int(fraction * Double(steps.count)))]
        }
        operation = nil
        finished(kind, outcome: stopRequested ? .stopped : .success, on: target, since: started, detail: "Simulated")

        if stopRequested {
            report(.warning, "Stopped.")
        } else {
            successes += 1
            report(.success, kind == .restore ? "Restore complete." : "Revive complete.")
            devices = DemoScenario.booted.devices
        }
    }
}
