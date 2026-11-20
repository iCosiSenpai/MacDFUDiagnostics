import Foundation
import CHPMBridge

// macdfu-vdm-helper — sends one USB-PD vendor message through the host's AppleHPM port controller.
//
// The app runs this as root, so the command line is parsed strictly: an unknown command, an unknown
// option or a malformed value is an error, never a silent fallback to a default port.

struct HelperOutput: Codable {
    let statusCode: Int32
    let usedRID: Int32
    let connected: Bool
    let isSource: Bool
    let usedT2Fallback: Bool
    let vdmReplyHeaderHex: String
    let hpmStatus: String
    let hostPlatform: String
    let message: String
}

enum HelperExit {
    static let success: Int32 = 0
    static let actionFailed: Int32 = 1
    static let usage: Int32 = 64 // EX_USAGE
}

let usage = "Usage: macdfu-vdm-helper <dfu|dfu-silicon|dfu-t2|reboot|serial|debugusb|probe> [--rid <0-31>] [--json]"

func action(named name: String) -> HPMActionType? {
    switch name {
    case "dfu", "dfu-auto": HPM_ACTION_DFU_AUTO
    case "dfu-silicon": HPM_ACTION_DFU_SILICON
    case "dfu-t2": HPM_ACTION_DFU_T2
    case "reboot": HPM_ACTION_REBOOT
    case "serial": HPM_ACTION_SERIAL
    case "debugusb", "kis": HPM_ACTION_DEBUGUSB
    case "probe": HPM_ACTION_PROBE
    default: nil
    }
}

func fail(_ text: String) -> Int32 {
    FileHandle.standardError.write(Data("\(text)\n\(usage)\n".utf8))
    return HelperExit.usage
}

func runHelper() -> Int32 {
    var args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else { return fail("Missing command.") }

    let commandName = args.removeFirst()
    guard let action = action(named: commandName) else {
        return fail("Unknown command: \(commandName)")
    }

    var targetRID: Int32 = -1
    var jsonOutput = false
    var index = 0
    while index < args.count {
        switch args[index] {
        case "--rid":
            guard index + 1 < args.count, let rid = Int32(args[index + 1]), (0...31).contains(rid) else {
                return fail("--rid needs a port number between 0 and 31.")
            }
            targetRID = rid
            index += 2
        case "--json":
            jsonOutput = true
            index += 1
        default:
            return fail("Unknown option: \(args[index])")
        }
    }

    var raw = hpm_execute_action(action, targetRID)
    let output = HelperOutput(
        statusCode: raw.status_code,
        usedRID: raw.used_rid,
        connected: raw.connected,
        isSource: raw.is_source,
        usedT2Fallback: raw.used_t2_fallback,
        vdmReplyHeaderHex: String(format: "0x%08X", raw.vdm_reply_header),
        hpmStatus: withUnsafePointer(to: &raw.hpm_status.0) { String(cString: $0) },
        hostPlatform: withUnsafePointer(to: &raw.host_platform.0) { String(cString: $0) },
        message: withUnsafePointer(to: &raw.message.0) { String(cString: $0) }
    )

    if jsonOutput {
        if let data = try? JSONEncoder().encode(output), let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    } else {
        print("[\(output.statusCode == 0 ? "OK" : "ERR \(output.statusCode)")] \(output.message)")
        print("Host: \(output.hostPlatform) | RID: \(output.usedRID) | Connected: \(output.connected) | Status: \(output.hpmStatus) | Reply: \(output.vdmReplyHeaderHex)")
    }

    return raw.status_code == 0 ? HelperExit.success : HelperExit.actionFailed
}

exit(runHelper())
