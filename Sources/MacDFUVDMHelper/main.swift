import Foundation
import CHPMBridge

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

func runHelper() -> Int32 {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let cmd = args.first else {
        print("Usage: macdfu-vdm-helper <dfu|dfu-silicon|dfu-t2|reboot|serial|debugusb|probe> [--rid <N>] [--json]")
        return 1
    }

    var targetRID: Int32 = -1
    var jsonOutput = false
    var i = 1
    while i < args.count {
        if args[i] == "--rid", i + 1 < args.count, let r = Int32(args[i + 1]) {
            targetRID = r
            i += 2
        } else if args[i] == "--json" {
            jsonOutput = true
            i += 1
        } else {
            i += 1
        }
    }

    let action: HPMActionType
    switch cmd.lowercased() {
    case "dfu", "dfu-auto":
        action = HPM_ACTION_DFU_AUTO
    case "dfu-silicon":
        action = HPM_ACTION_DFU_SILICON
    case "dfu-t2":
        action = HPM_ACTION_DFU_T2
    case "reboot":
        action = HPM_ACTION_REBOOT
    case "serial":
        action = HPM_ACTION_SERIAL
    case "debugusb", "kis":
        action = HPM_ACTION_DEBUGUSB
    case "probe":
        action = HPM_ACTION_PROBE
    default:
        print("Unknown command: \(cmd)")
        return 2
    }

    var rawResult = hpm_execute_action(action, targetRID)
    let hpmStatus = withUnsafePointer(to: &rawResult.hpm_status.0) { String(cString: $0) }
    let hostPlatform = withUnsafePointer(to: &rawResult.host_platform.0) { String(cString: $0) }
    let message = withUnsafePointer(to: &rawResult.message.0) { String(cString: $0) }

    let out = HelperOutput(
        statusCode: rawResult.status_code,
        usedRID: rawResult.used_rid,
        connected: rawResult.connected,
        isSource: rawResult.is_source,
        usedT2Fallback: rawResult.used_t2_fallback,
        vdmReplyHeaderHex: String(format: "0x%08X", rawResult.vdm_reply_header),
        hpmStatus: hpmStatus,
        hostPlatform: hostPlatform,
        message: message
    )

    if jsonOutput {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(out), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        print("[\(out.statusCode == 0 ? "OK" : "ERR \(out.statusCode)")] \(out.message)")
        print("Host: \(out.hostPlatform) | RID: \(out.usedRID) | Connected: \(out.connected) | Status: \(out.hpmStatus) | Reply: \(out.vdmReplyHeaderHex)")
    }

    return rawResult.status_code == 0 ? 0 : 1
}

exit(runHelper())
