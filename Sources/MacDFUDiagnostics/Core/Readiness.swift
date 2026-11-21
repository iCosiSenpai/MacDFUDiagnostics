import AppKit
import IOKit.ps
import Network
import Observation
import UserNotifications

/// What the app needs from this Mac and from its user, and whether it has it.
///
/// macOS asks for consent in one place only: notifications. Everything else is a condition rather than
/// a permission — an administrator password when a command is sent, the helper that ships in the app,
/// Apple Configurator for firmware — and is listed beside it so that "is everything all right?" has
/// one answer, in Settings › Advanced and in the welcome sheet.
@MainActor
@Observable
final class Readiness {
    enum NotificationState: Equatable, Sendable {
        case unknown
        case notAsked
        case allowed
        case denied
        /// Running outside an app bundle, where there is no notification centre to talk to.
        case unavailable
    }

    enum HelperState: Equatable, Sendable {
        case verified
        /// An ad-hoc development build: the helper is there, and nothing pins who signed it.
        case development
        case missing
        case rejected
    }

    private(set) var notifications: NotificationState = .unknown
    private(set) var helper: HelperState = .missing
    private(set) var isAdministrator = false
    private(set) var isOnline = true
    private(set) var isOnBattery = false

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var hasStarted = false

    /// The notification centre throws when the process has no bundle to speak for.
    private static var hasNotificationCenter: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: .global(qos: .utility))
        Task { await refresh() }
    }

    /// Reads everything again. Cheap, so it runs whenever the app comes to the front.
    func refresh() async {
        isAdministrator = Self.currentUserIsAdministrator()
        isOnBattery = Self.isRunningOnBattery()
        helper = await Task.detached { Self.readHelperState() }.value

        guard Self.hasNotificationCenter else {
            notifications = .unavailable
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = switch settings.authorizationStatus {
        case .authorized, .provisional: .allowed
        case .denied: .denied
        default: .notAsked
        }
    }

    /// Shows the system's consent prompt. It appears once; afterwards the choice lives in System Settings.
    func requestNotifications() async {
        guard Self.hasNotificationCenter else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }

    func openNotificationSettings() {
        let identifier = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(identifier)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Tells the user something finished while they were looking elsewhere. Says nothing when the app
    /// is in front: the window already shows it.
    func notify(title: String, body: String) {
        guard Self.hasNotificationCenter, notifications == .allowed, !NSApplication.shared.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        NSApplication.shared.requestUserAttention(.informationalRequest)
    }

    // MARK: - Checks

    nonisolated static func currentUserIsAdministrator() -> Bool {
        guard let admin = getgrnam("admin"), let user = getpwuid(getuid()) else { return false }
        var groups = [Int32](repeating: 0, count: 128)
        var count = Int32(groups.count)
        getgrouplist(user.pointee.pw_name, Int32(user.pointee.pw_gid), &groups, &count)
        return groups.prefix(Int(max(0, count))).contains(Int32(admin.pointee.gr_gid))
    }

    nonisolated static func isRunningOnBattery() -> Bool {
        guard let source = IOPSGetProvidingPowerSourceType(nil)?.takeUnretainedValue() else { return false }
        return (source as String) == kIOPMBatteryPowerKey
    }

    private nonisolated static func readHelperState() -> HelperState {
        guard let url = PrivilegedHelper.bundledHelperURL else { return .missing }
        guard CodeTrust.runningAppIsReleaseBuild else { return .development }
        do {
            try CodeTrust.verify(codeAt: url, requirement: CodeTrust.requirement(identifier: CodeTrust.helperIdentifier))
            return .verified
        } catch {
            return .rejected
        }
    }
}
