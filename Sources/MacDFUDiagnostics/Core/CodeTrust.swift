import Foundation
import Security

/// Who is allowed to sign code this app runs or installs.
///
/// Two things here are easy to get wrong and both end in running someone else's code:
/// - A signature that merely *verifies* says nothing about *who* signed it — an ad-hoc signature verifies
///   too. Every check below is made against an explicit requirement that names the team.
/// - Text printed by `codesign -dv` is not evidence: the signer chooses the identifier it prints. The
///   checks go through Security.framework and never compare strings from a tool's output.
enum CodeTrust {
    static let teamID = "6KV8L8WQ9D"
    static let appIdentifier = "com.macsenpai.MacDFUDiagnostics"
    static let helperIdentifier = "com.macsenpai.MacDFUDiagnostics.vdm-helper"

    enum Failure: LocalizedError {
        case unreadable(OSStatus)
        case badRequirement(OSStatus)
        case rejected(OSStatus)

        var errorDescription: String? {
            let status: OSStatus
            switch self {
            case .unreadable(let code), .badRequirement(let code), .rejected(let code): status = code
            }
            let text = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "\(text) (\(status))"
        }
    }

    /// Developer ID Application, issued to this team, for exactly this identifier.
    ///
    /// The team ID is quoted because it starts with a digit: unquoted, the requirement does not compile
    /// and would reject every build, good ones included.
    static func requirement(identifier: String) -> String {
        "anchor apple generic"
            + " and identifier \"\(identifier)\""
            + " and certificate 1[field.1.2.840.113635.100.6.2.6] exists"
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
            + " and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    /// Whether this very process is a Developer ID build of the app. Development builds are ad-hoc
    /// signed and answer `false`; they cannot pin their helper and cannot self-update.
    static let runningAppIsReleaseBuild: Bool = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              let requirement = try? compiled(requirement(identifier: appIdentifier)) else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }()

    /// Verifies code on disk — every architecture, nested code and sealed resources included — against
    /// a requirement. Throws unless it passes.
    static func verify(codeAt url: URL, requirement text: String) throws {
        var staticCode: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard created == errSecSuccess, let staticCode else { throw Failure.unreadable(created) }

        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        let status = SecStaticCodeCheckValidity(staticCode, flags, try compiled(text))
        guard status == errSecSuccess else { throw Failure.rejected(status) }
    }

    private static func compiled(_ text: String) throws -> SecRequirement {
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(text as CFString, [], &requirement)
        guard status == errSecSuccess, let requirement else { throw Failure.badRequirement(status) }
        return requirement
    }
}
