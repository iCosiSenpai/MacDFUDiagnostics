import Foundation

// MARK: - Target state

/// What a connected Apple device is doing, read from its USB product ID.
enum TargetState: String, Sendable {
    case dfu
    case portDFU
    case debugUSB
    case recovery
    case wtf
    case restoring
    case booted
    case cableFault
    case other

    static func from(productID: UInt16, productName: String, serial: String) -> TargetState {
        switch productID {
        case 0x1227: .dfu
        case 0xF014: .portDFU
        case 0x1881: .debugUSB
        case 0x1280, 0x1281: .recovery
        case 0x1222:
            // The T2 enumerates with the WTF product ID while it is really in DFU.
            productName.localizedCaseInsensitiveContains("Mac DFU Mode") || serial.contains("CPID:8012") ? .dfu : .wtf
        case 0x1338, 0x1339: .restoring
        case 0x1902: .booted
        case 0x7304: .cableFault
        default: .other
        }
    }

    /// The device can take a revive or a restore right now.
    var acceptsFirmware: Bool {
        self == .dfu || self == .portDFU || self == .debugUSB
    }
}

// MARK: - Host

struct HostPort: Identifiable, Equatable, Sendable {
    let rid: Int32
    let portNumber: UInt32
    let locationBase: UInt32
    /// The port carries the debug lines DFU needs.
    let isDFUCapable: Bool
    let name: String

    var id: Int32 { rid }
}

struct HostInfo: Equatable, Sendable {
    var board: String = ""
    var model: MacModel?
    var isAppleSilicon: Bool = false

    var name: String {
        model?.name ?? (board.isEmpty ? "Mac" : board)
    }
}

// MARK: - Target device

struct TargetDevice: Identifiable, Equatable, Sendable {
    let id: String
    let vendorID: UInt16
    let productID: UInt16
    let bcdDevice: UInt16
    let locationID: UInt32
    let productName: String
    let rawSerial: String
    let state: TargetState
    let cpid: UInt16?
    let bdid: UInt8?
    /// `0x`-prefixed hex, validated — safe to hand to `cfgutil --ecid`.
    let ecid: String?
    let iBootTag: String?
    let serialNumber: String?
    let model: MacModel?
    let hostPortRID: Int32?

    var isIntelT2: Bool {
        cpid == MacCatalog.t2ChipID || model?.architecture == .intelT2
    }

    /// The name to show: the Mac when it is known, otherwise whatever the device calls itself.
    var title: String {
        if let model { return model.name }
        return productName.isEmpty ? "Apple device" : productName
    }

    var usbID: String {
        String(format: "%04x:%04x", vendorID, productID)
    }
}

/// The identity a device packs into its USB serial-number string while in DFU or recovery.
struct DeviceIdentity: Equatable, Sendable {
    var cpid: UInt16?
    var bdid: UInt8?
    var ecid: String?
    var iBootTag: String?
    var serialNumber: String?

    /// Parses `CPID:8103 BDID:26 ECID:001A… SRTG:[iBoot-…]`.
    ///
    /// Every value comes from a USB descriptor, which is to say from whatever is plugged in: nothing
    /// here is trusted, and the ECID in particular is kept only if it is plain hex, because it is later
    /// passed to `cfgutil` on the command line.
    static func parse(serial: String, isPortDFU: Bool) -> DeviceIdentity {
        var identity = DeviceIdentity()
        var packedBoard: UInt64?

        for token in serial.split(whereSeparator: \.isWhitespace) {
            let parts = token.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let value = String(parts[1])
            let unbracketed = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

            switch parts[0].uppercased() {
            case "CPID":
                if !isPortDFU { identity.cpid = UInt16(value, radix: 16) }
            case "BDID":
                if isPortDFU {
                    packedBoard = UInt64(value, radix: 16)
                } else {
                    identity.bdid = UInt8(value, radix: 16)
                }
            case "ECID":
                identity.ecid = normalizedECID(value)
            case "SRTG":
                identity.iBootTag = printable(unbracketed)
            case "SRNM":
                identity.serialNumber = printable(unbracketed)
            default:
                break
            }
        }

        // In port DFU the USB-C controller reports chip and board packed into one 64-bit BDID field.
        if isPortDFU, let packedBoard {
            identity.cpid = UInt16((packedBoard >> 8) & 0xFFFF)
            identity.bdid = UInt8((packedBoard >> 24) & 0xFF)
        }

        // A running Mac reports `<chip, 8 hex digits>-<ECID, 16 hex digits>` instead.
        if identity.ecid == nil {
            let halves = serial.split(separator: "-")
            if halves.count == 2, halves[0].count == 8, halves[1].count == 16,
               let chip = UInt32(halves[0], radix: 16), let ecid = normalizedECID(String(halves[1])) {
                identity.cpid = identity.cpid ?? UInt16(truncatingIfNeeded: chip)
                identity.ecid = ecid
            }
        }

        return identity
    }

    /// `0x` + upper-case hex, or `nil` if the text is anything but 1–16 hex digits.
    static func normalizedECID(_ text: String) -> String? {
        var digits = Substring(text)
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") { digits = digits.dropFirst(2) }
        guard (1...16).contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        return "0x" + digits.uppercased()
    }

    /// Descriptor text with control characters removed and a sane length.
    private static func printable(_ text: String) -> String? {
        let cleaned = String(text.unicodeScalars.filter { $0.isASCII && $0.value >= 0x20 && $0.value < 0x7F }.prefix(64))
        return cleaned.isEmpty ? nil : cleaned
    }
}

// MARK: - Disks

struct DiskVolume: Identifiable, Equatable, Sendable {
    /// `disk5s1`
    let id: String
    let name: String
    /// Where the volume is mounted, when it is.
    let mountPoint: String?
}

struct ExternalDisk: Identifiable, Equatable, Sendable {
    /// `disk4` — always matches `^disk[0-9]+$`.
    let id: String
    let name: String
    let sizeBytes: Int64
    let bus: String
    let smartStatus: String?
    let volumes: [DiskVolume]

    /// The volumes a person would recognise: mounted where the Finder shows them.
    var visibleVolumes: [DiskVolume] {
        volumes.filter { $0.mountPoint?.hasPrefix("/Volumes/") == true }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    /// `diskutil` is only ever given identifiers of this shape.
    static func isValidIdentifier(_ text: String) -> Bool {
        text.wholeMatch(of: /disk[0-9]{1,4}/) != nil
    }
}

struct DiskCheck: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case running
        case passed
        case problems
    }

    var outcome: Outcome
    var output: String
}

enum BridgeState: Equatable, Sendable {
    case active
    case inactive
    case absent
}

// MARK: - Commands & operations

/// The vendor messages the helper can send. The raw value is the helper's command name.
enum VDMCommand: String, CaseIterable, Sendable {
    case dfu
    case dfuSilicon = "dfu-silicon"
    case dfuT2 = "dfu-t2"
    case restart = "reboot"
    case serial
    case debugUSB = "debugusb"
    case probe
}

struct Operation: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case vdm(VDMCommand)
        case revive
        case restore
        case diskCheck
    }

    let kind: Kind
    /// 0…1 when the tool reports it, otherwise indeterminate.
    var progress: Double?
    /// The tool's latest status line, already trimmed for display.
    var detail: String?

    var canStop: Bool {
        kind == .revive || kind == .restore
    }
}

// MARK: - Activity

enum LogLevel: String, Sendable {
    case info
    case success
    case warning
    case failure
}

struct LogEntry: Identifiable, Equatable, Sendable {
    let id = UUID()
    let date = Date()
    let level: LogLevel
    let message: LocalizedStringResource
    /// Untranslated technical detail (tool output, reply codes).
    var detail: String?

    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool { lhs.id == rhs.id }
}

/// A short, transient message for the main window.
struct Notice: Identifiable, Equatable, Sendable {
    let id = UUID()
    let level: LogLevel
    let message: LocalizedStringResource

    static func == (lhs: Notice, rhs: Notice) -> Bool { lhs.id == rhs.id }
}
