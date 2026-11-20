import Foundation

/// Runs the bundled VDM helper as root, behind the system's administrator prompt.
///
/// The helper is the one piece of this app that runs with full privileges, so what gets executed is
/// decided with some care:
/// - Only the helper shipped next to the app's own executable is ever used — no search through
///   `/usr/local`, Homebrew or any other place an unprivileged process could have written to.
/// - The file is first copied into a directory only root can touch, and it is that copy that is checked
///   and run. Checking the original and then running it would leave a window in which it could be
///   swapped; nothing but root can swap the copy.
/// - In a release build the copy must carry this team's Developer ID signature or it is not run.
enum PrivilegedHelper {
    struct Reply: Decodable, Sendable {
        let statusCode: Int
        let usedRID: Int
        let connected: Bool
        let usedT2Fallback: Bool
        let vdmReplyHeaderHex: String
        let hpmStatus: String
        let message: String
    }

    enum Outcome: Sendable {
        case reply(Reply)
        case cancelled
        /// The helper was refused before it ran: missing, or its signature did not check out.
        case refused
        case failed(String)
    }

    /// The helper that ships beside the running executable — in the app bundle and in a SwiftPM build
    /// directory alike.
    static var bundledHelperURL: URL? {
        guard let directory = Bundle.main.executableURL?.deletingLastPathComponent() else { return nil }
        let url = directory.appending(path: "macdfu-vdm-helper")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private enum Exit {
        static let noScratch = 70
        static let copyFailed = 71
        static let badSignature = 72
    }

    static func run(_ command: VDMCommand, rid: Int32, prompt: String) async -> Outcome {
        guard let helper = bundledHelperURL else { return .refused }

        let script = rootScript(
            helperPath: helper.path,
            requirement: CodeTrust.runningAppIsReleaseBuild ? CodeTrust.requirement(identifier: CodeTrust.helperIdentifier) : nil,
            command: command,
            rid: rid
        )

        // The script and the prompt travel as arguments, so AppleScript never parses either of them.
        let result = await ProcessRunner.run("/usr/bin/osascript", [
            "-e", "on run argv",
            "-e", "do shell script (item 1 of argv) with prompt (item 2 of argv) with administrator privileges",
            "-e", "end run",
            script,
            prompt,
        ])

        if result.succeeded {
            guard let data = lastJSONLine(of: result.output),
                  let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
                return .failed(result.output)
            }
            return .reply(reply)
        }
        // osascript reports "User canceled." as error -128; the process itself just exits non-zero.
        if result.output.contains("(-128)") { return .cancelled }
        if result.output.contains("(\(Exit.badSignature))") || result.output.contains("(\(Exit.copyFailed))") { return .refused }
        return .failed(result.output)
    }

    /// The commands root runs. Everything that varies is quoted; the command name and the port number
    /// cannot carry shell syntax by construction (an enum raw value and an integer).
    static func rootScript(helperPath: String, requirement: String?, command: VDMCommand, rid: Int32) -> String {
        let quote = ProcessRunner.shellQuoted
        var lines = [
            "umask 077",
            "D=$(/usr/bin/mktemp -d /private/var/run/macdfu.XXXXXXXX) || exit \(Exit.noScratch)",
            "trap '/bin/rm -rf \"$D\"' EXIT",
            "/bin/cp \(quote(helperPath)) \"$D/helper\" || exit \(Exit.copyFailed)",
        ]
        if let requirement {
            lines.append("/usr/bin/codesign --verify --strict -R \(quote("=" + requirement)) \"$D/helper\" || exit \(Exit.badSignature)")
        }
        // The helper exits non-zero when the action fails; its JSON already says so, and a non-zero
        // exit would make osascript discard that JSON, hence the explicit `exit 0`.
        lines.append("\"$D/helper\" \(command.rawValue) --rid \(rid) --json")
        lines.append("exit 0")
        return lines.joined(separator: "\n")
    }

    private static func lastJSONLine(of output: String) -> Data? {
        output.split(whereSeparator: \.isNewline)
            .last { $0.hasPrefix("{") && $0.hasSuffix("}") }
            .map { Data($0.utf8) }
    }
}
