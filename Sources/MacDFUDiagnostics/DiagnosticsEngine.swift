import Foundation
import Observation
import CHPMBridge

enum TargetUSBState: String, Equatable, Sendable {
    case dfu
    case portDfu
    case kis
    case recovery
    case wtf
    case restore
    case booted
    case billboard
    case other

    func label(in lang: AppLanguage) -> String {
        switch self {
        case .dfu:
            lang.text("Modalità DFU (BootROM)", "DFU Mode (BootROM)")
        case .portDfu:
            lang.text("Port DFU (Controller USB-C)", "Port DFU (USB-C Controller)")
        case .kis:
            lang.text("Debug USB (KIS 05ac:1881)", "Debug USB (KIS 05ac:1881)")
        case .recovery:
            lang.text("Modalità Recovery / iBoot", "Recovery / iBoot Mode")
        case .wtf:
            lang.text("Modalità WTF (05ac:1222)", "WTF Mode (05ac:1222)")
        case .restore:
            lang.text("Restore Ramdisk (In corso)", "Restore Ramdisk (Active)")
        case .booted:
            lang.text("Mac Acceso (RemoteXPC 05ac:1902)", "Booted Mac (RemoteXPC 05ac:1902)")
        case .billboard:
            lang.text("USB Billboard (Errore Cavo/Alt-Mode)", "USB Billboard (Cable/Alt-Mode Error)")
        case .other:
            lang.text("Dispositivo USB Apple", "Apple USB Device")
        }
    }

    static func from(pid: UInt16, productName: String, serial: String) -> TargetUSBState {
        switch pid {
        case 0x1227:
            return .dfu
        case 0xF014:
            return .portDfu
        case 0x1881:
            return .kis
        case 0x1280, 0x1281:
            return .recovery
        case 0x1222:
            if productName.localizedCaseInsensitiveContains("Mac DFU Mode") || serial.contains("CPID:8012") {
                return .dfu
            }
            return .wtf
        case 0x1338, 0x1339:
            return .restore
        case 0x1902:
            return .booted
        case 0x7304:
            return .billboard
        default:
            return .other
        }
    }

    var isRestorableDFU: Bool {
        self == .dfu || self == .portDfu || self == .kis
    }
}

struct HostPortStatus: Identifiable, Equatable, Sendable {
    let rid: Int32
    let portNumber: UInt32
    let locationBase: UInt32
    let isDFUCapable: Bool
    let locationName: String
    let ioPath: String

    var id: Int32 { rid }

    var locationBaseHex: String {
        String(format: "0x%08X", locationBase)
    }
}

struct DetectedAppleUSBDevice: Identifiable, Equatable, Sendable {
    let id: String
    let vendorID: UInt16
    let productID: UInt16
    let bcdDevice: UInt16
    let deviceClass: UInt8
    let locationID: UInt32
    let productName: String
    let rawSerial: String
    let state: TargetUSBState
    let cpid: UInt16?
    let bdid: UInt8?
    let ecidHex: String?
    let srtg: String?
    let hardwareSerial: String?
    let resolvedSpec: CompatibleMacSpec?
    let hostPortRID: Int32?
    let hostPortLocation: String?
    let isOnHostDFUPort: Bool

    var vidPidHex: String {
        String(format: "%04x:%04x", vendorID, productID)
    }

    var locationHex: String {
        String(format: "0x%08X", locationID)
    }

    var bcdVersionString: String {
        String(format: "%x.%02x", bcdDevice >> 8, bcdDevice & 0xFF)
    }

    func displayTitle(in lang: AppLanguage) -> String {
        if let spec = resolvedSpec {
            return spec.marketingName
        }
        if let cpid, let bdid {
            return String(
                format: lang.text("Mac / Dispositivo Apple (CPID: 0x%04X, BDID: 0x%02X)", "Apple Mac / Device (CPID: 0x%04X, BDID: 0x%02X)"),
                cpid, bdid
            )
        }
        return productName.isEmpty
            ? lang.text("Dispositivo Apple (\(vidPidHex))", "Apple Device (\(vidPidHex))")
            : productName
    }

    var isIntelT2: Bool {
        cpid == 0x8012 || resolvedSpec?.category == .intelT2
    }
}

struct ExternalTargetDisk: Identifiable, Equatable, Sendable {
    let id: String
    let deviceIdentifier: String
    let mediaName: String
    let sizeBytes: Int64
    let busProtocol: String
    let smartStatus: String
    let partitions: [String]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct DiagnosticLogEntry: Identifiable, Equatable, Sendable {
    enum Level: String, Equatable, Sendable {
        case info = "INFO"
        case success = "OK"
        case warning = "WARN"
        case error = "ERR"
    }
    let id: UUID
    let timestamp: Date
    let level: Level
    let messageIT: String
    let messageEN: String

    func message(in lang: AppLanguage) -> String {
        lang == .it ? messageIT : messageEN
    }
}

enum ThunderboltBridgeState: Equatable, Sendable {
    case active
    case inactive
    case notConfigured

    func label(in lang: AppLanguage) -> String {
        switch self {
        case .active:
            lang.text("Attivo (bridge0 connesso via cavo Thunderbolt/USB4)", "Active (bridge0 linked over Thunderbolt/USB4 cable)")
        case .inactive:
            lang.text("Inattivo (interfaccia bridge0 presente ma nessun link attivo)", "Inactive (bridge0 interface present, no active link)")
        case .notConfigured:
            lang.text("Non configurato", "Not configured")
        }
    }
}

@MainActor
@Observable
final class DiagnosticsEngine {
    // Host State
    private(set) var hostPlatformName: String = "Unknown"
    private(set) var hostUnlockKeyHex: String = "0x00000000"
    private(set) var hostMacSpec: CompatibleMacSpec?
    private(set) var isAppleSiliconHost: Bool = false
    private(set) var hostFreeSpaceBytes: Int64 = 0
    private(set) var cfgutilPath: String?
    private(set) var vdmHelperPath: String?
    private(set) var macvdmtoolPath: String?

    static func appleDFUPortSupportURL(for lang: AppLanguage) -> URL {
        URL(string: lang == .it ? "https://support.apple.com/it-it/120694" : "https://support.apple.com/en-us/120694")!
    }

    static func appleReviveRestoreSupportURL(for lang: AppLanguage) -> URL {
        URL(string: lang == .it ? "https://support.apple.com/it-it/108900" : "https://support.apple.com/en-us/108900")!
    }

    // Live Hardware State
    private(set) var hostPorts: [HostPortStatus] = []
    private(set) var detectedUSBDevices: [DetectedAppleUSBDevice] = []
    private(set) var externalTargetDisks: [ExternalTargetDisk] = []
    private(set) var serialConsoleDevices: [String] = []
    private(set) var thunderboltBridgeState: ThunderboltBridgeState = .notConfigured

    // Operation State
    private(set) var isBusy: Bool = false
    private(set) var currentOperationTitleIT: String?
    private(set) var currentOperationTitleEN: String?
    private(set) var operationProgress: Double?
    private(set) var logs: [DiagnosticLogEntry] = []
    private(set) var diskDiagnosticOutput: String = ""

    var selectedHostRID: Int32 = 0
    var selectedIPSWURL: URL?

    private var monitorTask: Task<Void, Never>?

    init() {
        refreshHostCapabilities()
        refreshAllHardware()
    }

    func currentOperationTitle(in lang: AppLanguage) -> String? {
        lang == .it ? currentOperationTitleIT : currentOperationTitleEN
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshUSBAndPorts()
                try? await Task.sleep(for: .seconds(2.5))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func appendLog(_ level: DiagnosticLogEntry.Level, it: String, en: String? = nil) {
        let entry = DiagnosticLogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            messageIT: it,
            messageEN: en ?? it
        )
        logs.append(entry)
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Host Capabilities
    func refreshHostCapabilities() {
        #if arch(arm64)
        isAppleSiliconHost = true
        #else
        isAppleSiliconHost = false
        #endif

        var nameBuf = [UInt8](repeating: 0, count: 64)
        var key: UInt32 = 0
        let ok = nameBuf.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: CChar.self, capacity: 64) { cPtr in
                hpm_get_host_platform(cPtr, 64, &key)
            }
        }
        if ok {
            let end = nameBuf.firstIndex(of: 0) ?? nameBuf.count
            hostPlatformName = String(decoding: nameBuf[..<end], as: UTF8.self)
            hostUnlockKeyHex = String(format: "0x%08X", key)
            hostMacSpec = CompatibilityCatalog.lookupByBoardConfig(hostPlatformName)
        }

        if let vals = try? URL.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]) {
            let cap1 = vals.volumeAvailableCapacityForImportantUsage ?? 0
            let cap2 = Int64(vals.volumeAvailableCapacity ?? 0)
            hostFreeSpaceBytes = cap1 > 0 && cap2 > 0 ? min(cap1, cap2) : max(cap1, cap2)
        }

        let cfgCandidates = [
            "/Applications/Apple Configurator.app/Contents/MacOS/cfgutil",
            "/usr/local/bin/cfgutil",
            "/opt/homebrew/bin/cfgutil",
            "/Applications/Apple Configurator 2.app/Contents/MacOS/cfgutil"
        ]
        cfgutilPath = cfgCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }

        let execDir = Bundle.main.executableURL?.deletingLastPathComponent().path ?? ""
        let helperCandidates = [
            "\(execDir)/macdfu-vdm-helper",
            "/Users/macsenpai/dev/MacDFUDiagnostics/.build/release/macdfu-vdm-helper",
            "/Users/macsenpai/dev/MacDFUDiagnostics/.build/debug/macdfu-vdm-helper"
        ]
        vdmHelperPath = helperCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }

        let vdmCandidates = [
            "/Users/macsenpai/macvdmtool/macvdmtool",
            "/usr/local/bin/macvdmtool",
            "/opt/homebrew/bin/macvdmtool"
        ]
        macvdmtoolPath = vdmCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func refreshAllHardware() {
        refreshHostCapabilities()
        refreshUSBAndPorts()
        Task {
            await refreshExternalTargetDisks()
            await refreshThunderboltBridge()
        }
    }

    // MARK: - USB & AppleHPM Port Topology Scan
    func refreshUSBAndPorts() {
        var rawPorts = [HPMHostPortInfo](repeating: HPMHostPortInfo(), count: 16)
        let portCount = hpm_list_host_ports(&rawPorts, 16)
        var parsedPorts: [HostPortStatus] = []
        for i in 0..<portCount {
            var p = rawPorts[i]
            let locName = withUnsafePointer(to: &p.location_name.0) { String(cString: $0) }
            let ioPath = withUnsafePointer(to: &p.io_path.0) { String(cString: $0) }
            parsedPorts.append(HostPortStatus(
                rid: p.rid,
                portNumber: p.port_number,
                locationBase: p.location_base,
                isDFUCapable: p.is_dfu_capable,
                locationName: locName,
                ioPath: ioPath
            ))
        }
        parsedPorts.sort { $0.rid < $1.rid }
        if hostPorts != parsedPorts {
            hostPorts = parsedPorts
            if !hostPorts.contains(where: { $0.rid == selectedHostRID }),
               let firstDFU = hostPorts.first(where: { $0.isDFUCapable }) ?? hostPorts.first {
                selectedHostRID = firstDFU.rid
            }
        }

        if let devFiles = try? FileManager.default.contentsOfDirectory(atPath: "/dev") {
            let consoles = devFiles
                .filter { $0.hasPrefix("cu.debug") || $0.hasPrefix("cu.kis-") }
                .map { "/dev/\($0)" }
                .sorted()
            if serialConsoleDevices != consoles {
                serialConsoleDevices = consoles
            }
        }

        var rawDevs = [HPMUSBDeviceInfo](repeating: HPMUSBDeviceInfo(), count: 32)
        let devCount = hpm_list_apple_usb_devices(&rawDevs, 32)
        var parsedDevs: [DetectedAppleUSBDevice] = []

        for i in 0..<devCount {
            var d = rawDevs[i]
            let prodName = withUnsafePointer(to: &d.product_name.0) { String(cString: $0) }
            let serialStr = withUnsafePointer(to: &d.serial_number.0) { String(cString: $0) }
            let state = TargetUSBState.from(pid: d.product_id, productName: prodName, serial: serialStr)

            let isMacTargetCandidate = (state != .other) ||
                serialStr.contains("CPID:") ||
                prodName.localizedCaseInsensitiveContains("DFU") ||
                prodName.localizedCaseInsensitiveContains("Recovery") ||
                prodName.localizedCaseInsensitiveContains("Apple Mobile Device") ||
                prodName.localizedCaseInsensitiveContains("Mac")

            if !isMacTargetCandidate { continue }

            let (cpid, bdid, ecidHex, srtg, srnm) = Self.parseSerialFields(serialStr, isPortDFU: state == .portDfu)
            var spec: CompatibleMacSpec?
            if let cpid, let bdid {
                spec = CompatibilityCatalog.lookup(cpid: cpid, bdid: bdid)
            } else if state == .booted {
                spec = CompatibilityCatalog.lookupByBootedBCDDevice(d.bcd_device)
            }

            let hwSerial: String? = srnm ?? (state == .booted && !serialStr.isEmpty ? serialStr : nil)
            let locBase = d.location_id & 0xFF000000
            let matchedPort = parsedPorts.first { $0.locationBase != 0 && $0.locationBase == locBase }

            let uniqueID = "\(String(format: "%04x:%04x", d.vendor_id, d.product_id))-\(d.location_id)-\(ecidHex ?? serialStr)"
            parsedDevs.append(DetectedAppleUSBDevice(
                id: uniqueID,
                vendorID: d.vendor_id,
                productID: d.product_id,
                bcdDevice: d.bcd_device,
                deviceClass: d.device_class,
                locationID: d.location_id,
                productName: prodName,
                rawSerial: serialStr,
                state: state,
                cpid: cpid ?? spec?.cpid,
                bdid: bdid ?? spec?.bdid,
                ecidHex: ecidHex,
                srtg: srtg,
                hardwareSerial: hwSerial,
                resolvedSpec: spec,
                hostPortRID: matchedPort?.rid,
                hostPortLocation: matchedPort?.locationName,
                isOnHostDFUPort: matchedPort?.isDFUCapable ?? false
            ))
        }

        if detectedUSBDevices != parsedDevs {
            detectedUSBDevices = parsedDevs
        }
    }

    static func parseSerialFields(_ serial: String, isPortDFU: Bool) -> (cpid: UInt16?, bdid: UInt8?, ecidHex: String?, srtg: String?, srnm: String?) {
        var cpid: UInt16?
        var bdid: UInt8?
        var packedBDID: UInt64?
        var ecidHex: String?
        var srtg: String?
        var srnm: String?

        for token in serial.split(whereSeparator: \.isWhitespace) {
            let parts = token.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).uppercased()
            let val = String(parts[1])
            let unbracketed = val.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

            switch key {
            case "CPID":
                if !isPortDFU {
                    cpid = UInt16(val, radix: 16)
                }
            case "BDID":
                if isPortDFU {
                    packedBDID = UInt64(val, radix: 16)
                } else {
                    bdid = UInt8(val, radix: 16)
                }
            case "ECID":
                let clean = val.replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
                ecidHex = "0x" + clean.uppercased()
            case "SRTG":
                srtg = unbracketed
            case "SRNM":
                srnm = unbracketed
            default:
                break
            }
        }

        if isPortDFU, let packed = packedBDID {
            cpid = UInt16((packed >> 8) & 0xFFFF)
            bdid = UInt8((packed >> 24) & 0xFF)
        }

        if ecidHex == nil, serial.contains("-") {
            let dashParts = serial.split(separator: "-")
            if dashParts.count == 2, dashParts[0].count == 8, dashParts[1].count == 16 {
                cpid = cpid ?? UInt16(dashParts[0], radix: 16)
                ecidHex = "0x" + String(dashParts[1]).uppercased()
            }
        }

        return (cpid, bdid, ecidHex, srtg, srnm)
    }

    // MARK: - VDM Execution
    func executeVDMCommand(_ command: String, titleIT: String, titleEN: String) async {
        guard !isBusy else { return }
        refreshHostCapabilities()

        guard isAppleSiliconHost else {
            appendLog(
                .error,
                it: "I comandi VDM AppleHPM richiedono un Mac Host con Apple Silicon (arm64).",
                en: "AppleHPM VDM commands require an Apple Silicon Host Mac (arm64)."
            )
            return
        }

        isBusy = true
        currentOperationTitleIT = titleIT
        currentOperationTitleEN = titleEN
        operationProgress = nil
        defer {
            isBusy = false
            currentOperationTitleIT = nil
            currentOperationTitleEN = nil
        }

        let targetRID = selectedHostRID
        appendLog(
            .info,
            it: "Avvio comando VDM '\(command)' sulla porta Host AppleHPM RID=\(targetRID)...",
            en: "Starting VDM command '\(command)' on Host AppleHPM port RID=\(targetRID)..."
        )

        if let helper = vdmHelperPath {
            let shellCmd = "\(Self.shellQuoted(helper)) \(command) --rid \(targetRID) --json"
            let (rc, output) = await Self.runPrivilegedShellScript(shellCmd)
            if rc == -128 {
                appendLog(
                    .warning,
                    it: "Autenticazione amministratore annullata dall'utente.",
                    en: "Administrator authentication cancelled by user."
                )
                return
            }

            if let data = output.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = parsed["message"] as? String,
               let status = parsed["statusCode"] as? Int {
                let t2Fallback = (parsed["usedT2Fallback"] as? Bool) ?? false
                let replyHex = (parsed["vdmReplyHeaderHex"] as? String) ?? ""
                if status == 0 {
                    appendLog(
                        .success,
                        it: "\(msg) [RID=\(targetRID), Reply=\(replyHex)\(t2Fallback ? ", Fallback Intel T2 0x105/0x80020000" : "")]",
                        en: "\(msg) [RID=\(targetRID), Reply=\(replyHex)\(t2Fallback ? ", Intel T2 Fallback 0x105/0x80020000" : "")]"
                    )
                } else {
                    appendLog(
                        .error,
                        it: "\(msg) (codice \(status))",
                        en: "\(msg) (error code \(status))"
                    )
                }
            } else if rc == 0 {
                let text = output.isEmpty ? "OK" : output
                appendLog(.success, it: "Comando VDM '\(command)' completato: \(text)", en: "VDM command '\(command)' completed: \(text)")
            } else {
                appendLog(.error, it: "Errore VDM (rc=\(rc)): \(output)", en: "VDM Error (rc=\(rc)): \(output)")
            }
        } else if let legacyTool = macvdmtoolPath {
            let mappedCmd = (command == "dfu-silicon" || command == "dfu-t2") ? "dfu" : command
            let shellCmd = "\(Self.shellQuoted(legacyTool)) \(mappedCmd)"
            let (rc, output) = await Self.runPrivilegedShellScript(shellCmd)
            if rc == 0 {
                appendLog(.success, it: "macvdmtool (\(mappedCmd)): \(output)", en: "macvdmtool (\(mappedCmd)): \(output)")
            } else {
                appendLog(.error, it: "macvdmtool fallito (rc=\(rc)): \(output)", en: "macvdmtool failed (rc=\(rc)): \(output)")
            }
        } else {
            appendLog(
                .error,
                it: "Né macdfu-vdm-helper né macvdmtool sono stati trovati. Esegui `./build-app.sh`.",
                en: "Neither macdfu-vdm-helper nor macvdmtool was found. Run `./build-app.sh`."
            )
        }

        try? await Task.sleep(for: .seconds(1.5))
        refreshUSBAndPorts()
    }

    // MARK: - Revive & Restore via Apple Configurator `cfgutil`
    func executeCfgutilAction(mode: String, device: DetectedAppleUSBDevice) async {
        guard !isBusy else { return }
        refreshHostCapabilities()

        guard let cfg = cfgutilPath else {
            appendLog(
                .error,
                it: "cfgutil non trovato. Installa Apple Configurator dal Mac App Store.",
                en: "cfgutil not found. Install Apple Configurator from the Mac App Store."
            )
            return
        }

        var args = ["--progress"]
        if let ecid = device.ecidHex {
            args += ["-e", ecid]
        }

        if mode == "restore" {
            if device.isIntelT2 {
                let targetID = device.resolvedSpec?.dfuTargetIdentifier ?? "iBridge2,x"
                appendLog(
                    .info,
                    it: "Target Intel T2 (\(targetID)) rilevato: cfgutil scaricherà automaticamente il firmware bridgeOS senza bisogno di un IPSW UniversalMac.",
                    en: "Intel T2 target (\(targetID)) detected: cfgutil will automatically download bridgeOS firmware without needing a UniversalMac IPSW."
                )
            } else if let ipsw = selectedIPSWURL {
                if let fileSize = (try? ipsw.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    let requiredSpace = Int64(fileSize) + (2 << 30)
                    if hostFreeSpaceBytes > 0 && hostFreeSpaceBytes < requiredSpace {
                        let missingStr = ByteCountFormatter.string(fromByteCount: requiredSpace - hostFreeSpaceBytes, countStyle: .file)
                        appendLog(
                            .error,
                            it: "Spazio su disco insufficiente sull'Host per decomprimere l'IPSW. Libera almeno \(missingStr).",
                            en: "Insufficient free disk space on the Host to unpack the IPSW. Free up at least \(missingStr)."
                        )
                        return
                    }
                }
                args += ["restore", "-I", ipsw.path(percentEncoded: false)]
            } else {
                args += ["restore"]
                appendLog(
                    .info,
                    it: "Nessun IPSW locale selezionato: cfgutil scaricherà l'ultimo IPSW firmato dai server Apple.",
                    en: "No local IPSW selected: cfgutil will download the latest signed IPSW from Apple servers."
                )
            }
        } else {
            args += ["revive"]
        }

        isBusy = true
        currentOperationTitleIT = mode == "restore" ? "Restore (Ripristino) in corso..." : "Revive (Rianimazione) in corso..."
        currentOperationTitleEN = mode == "restore" ? "Restoring device..." : "Reviving device..."
        operationProgress = 0.0
        appendLog(.info, it: "Esecuzione: cfgutil \(args.joined(separator: " "))", en: "Running: cfgutil \(args.joined(separator: " "))")

        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "DFU Revive/Restore via cfgutil"
        )
        defer {
            ProcessInfo.processInfo.endActivity(activity)
            isBusy = false
            currentOperationTitleIT = nil
            currentOperationTitleEN = nil
            operationProgress = nil
            refreshUSBAndPorts()
        }

        let status = await Task.detached { () -> Int32 in
            let proc = Process()
            proc.executableURL = URL(filePath: cfg)
            proc.arguments = args
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                let text = String(decoding: data, as: UTF8.self)
                Task { @MainActor in
                    for rawLine in text.split(whereSeparator: \.isNewline) {
                        let clean = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty, !clean.hasPrefix("{"), !clean.hasPrefix("}") else { continue }
                        if let pctMatch = clean.matches(of: /(\d{1,3}(?:\.\d+)?)\s*%/).last,
                           let pct = Double(pctMatch.1), pct <= 100 {
                            self.operationProgress = pct / 100.0
                        }
                        self.appendLog(.info, it: "[cfgutil] \(clean)", en: "[cfgutil] \(clean)")
                    }
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus
            } catch {
                return -1
            }
        }.value

        if status == 0 {
            appendLog(
                .success,
                it: "\(mode.capitalized) completato con successo! Il Mac target si riavvierà automaticamente.",
                en: "\(mode.capitalized) completed successfully! The target Mac will restart automatically."
            )
            if device.isIntelT2 && mode == "restore" {
                appendLog(
                    .warning,
                    it: "NOTA INTEL T2: bridgeOS e l'SSD sono stati inizializzati. Ora avvia il Mac Intel T2 tenendo premuto Option-Command-R (Internet Recovery) per installare macOS.",
                    en: "INTEL T2 NOTE: bridgeOS and internal SSD have been erased. Now boot the Intel T2 Mac holding Option-Command-R (Internet Recovery) to install macOS."
                )
            }
        } else {
            appendLog(
                .error,
                it: "Operazione cfgutil '\(mode)' terminata con codice di errore \(status).",
                en: "cfgutil '\(mode)' operation failed with exit code \(status)."
            )
        }
    }

    // MARK: - Target Disk Mode & Thunderbolt Bridge Diagnostics
    func refreshExternalTargetDisks() async {
        let (_, xmlOut) = await Self.runProcess("/usr/sbin/diskutil", ["list", "-plist", "external"])
        guard let plistData = xmlOut.data(using: .utf8),
              let root = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let wholeDisks = root["WholeDisks"] as? [String] else {
            externalTargetDisks = []
            return
        }

        var found: [ExternalTargetDisk] = []
        let allDisksAndParts = (root["AllDisksAndPartitions"] as? [[String: Any]]) ?? []

        for diskID in wholeDisks {
            let (_, infoXML) = await Self.runProcess("/usr/sbin/diskutil", ["info", "-plist", diskID])
            guard let infoData = infoXML.data(using: .utf8),
                  let info = try? PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any] else {
                continue
            }

            let mediaName = (info["MediaName"] as? String) ?? "External Target Disk"
            let sizeBytes = (info["TotalSize"] as? Int64) ?? Int64((info["TotalSize"] as? Int) ?? 0)
            let busProto = (info["BusProtocol"] as? String) ?? "USB/Thunderbolt"
            let smart = (info["SMARTStatus"] as? String) ?? "N/A"

            var partNames: [String] = []
            if let entry = allDisksAndParts.first(where: { ($0["DeviceIdentifier"] as? String) == diskID }) {
                if let parts = entry["Partitions"] as? [[String: Any]] {
                    for p in parts {
                        if let pid = p["DeviceIdentifier"] as? String {
                            let vol = (p["VolumeName"] as? String) ?? (p["Content"] as? String) ?? ""
                            partNames.append(vol.isEmpty ? pid : "\(pid) (\(vol))")
                        }
                    }
                }
                if let apfsVols = entry["APFSVolumes"] as? [[String: Any]] {
                    for v in apfsVols {
                        if let vid = v["DeviceIdentifier"] as? String {
                            let vol = (v["VolumeName"] as? String) ?? "APFS Volume"
                            partNames.append("\(vid) [\(vol)]")
                        }
                    }
                }
            }

            found.append(ExternalTargetDisk(
                id: diskID,
                deviceIdentifier: diskID,
                mediaName: mediaName,
                sizeBytes: sizeBytes,
                busProtocol: busProto,
                smartStatus: smart,
                partitions: partNames
            ))
        }
        externalTargetDisks = found
    }

    func runTargetDiskVerification(diskIdentifier: String) async {
        guard !isBusy else { return }
        isBusy = true
        currentOperationTitleIT = "Verifica Disco Target (\(diskIdentifier))..."
        currentOperationTitleEN = "Verifying Target Disk (\(diskIdentifier))..."
        diskDiagnosticOutput = "Running `diskutil info` & `diskutil verifyDisk \(diskIdentifier)`...\n"
        appendLog(
            .info,
            it: "Avvio verifica Target Disk Mode su /dev/\(diskIdentifier)...",
            en: "Starting Target Disk Mode verification on /dev/\(diskIdentifier)..."
        )

        defer {
            isBusy = false
            currentOperationTitleIT = nil
            currentOperationTitleEN = nil
        }

        let (_, infoText) = await Self.runProcess("/usr/sbin/diskutil", ["info", diskIdentifier])
        diskDiagnosticOutput += "=== DISKUTIL INFO (\(diskIdentifier)) ===\n\(infoText)\n\n"

        let (rc, verifyText) = await Self.runProcess("/usr/sbin/diskutil", ["verifyDisk", diskIdentifier])
        diskDiagnosticOutput += "=== VERIFY DISK (rc=\(rc)) ===\n\(verifyText)\n"

        if rc == 0 {
            appendLog(
                .success,
                it: "Verifica di /dev/\(diskIdentifier) completata senza errori.",
                en: "Verification of /dev/\(diskIdentifier) completed with no errors."
            )
        } else {
            appendLog(
                .warning,
                it: "Verifica di /dev/\(diskIdentifier) ha riportato avvisi/errori (rc=\(rc)). Controlla il report.",
                en: "Verification of /dev/\(diskIdentifier) reported warnings/errors (rc=\(rc)). Check the report."
            )
        }
    }

    func refreshThunderboltBridge() async {
        let (rc, out) = await Self.runProcess("/sbin/ifconfig", ["bridge0"])
        if rc == 0 && !out.isEmpty {
            thunderboltBridgeState = out.contains("status: active") ? .active : .inactive
        } else {
            thunderboltBridgeState = .notConfigured
        }
    }

    // MARK: - Process Execution Helpers
    nonisolated static func shellQuoted(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated static func runProcess(_ launchPath: String, _ arguments: [String]) async -> (Int32, String) {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(filePath: launchPath)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                return (process.terminationStatus, output)
            } catch {
                return (-1, error.localizedDescription)
            }
        }.value
    }

    nonisolated static func runPrivilegedShellScript(_ shellCommand: String) async -> (Int32, String) {
        await runProcess("/usr/bin/osascript", [
            "-e", "on run argv",
            "-e", "do shell script (item 1 of argv) & \" 2>&1\" with administrator privileges",
            "-e", "end run",
            shellCommand
        ])
    }
}
