import SwiftUI

@main
struct MacDFUStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var engine = DiagnosticsEngine(demo: LaunchOptions.demo)
    @State private var preferences = Preferences()
    @State private var updater = UpdateManager()
    @State private var navigation = Navigation()
    @State private var readiness = Readiness()
    // A demo keeps its history in memory: simulated work has no place in the real record.
    @State private var history = History(fileURL: LaunchOptions.demo == nil ? History.defaultFileURL : nil)

    var body: some Scene {
        // One window: the app drives one piece of hardware, and two windows would only disagree.
        Window("Mac DFU Studio", id: "main") {
            RootView()
                .frame(minWidth: 820, minHeight: 560)
                .environment(engine)
                .environment(preferences)
                .environment(updater)
                .environment(navigation)
                .environment(readiness)
                .environment(history)
                .language(preferences.language)
                .onAppear {
                    appDelegate.navigation = navigation
                    appDelegate.engine = engine
                    preferences.applyAppearance()
                    readiness.start()
                    engine.onFinish = { record in
                        history.add(record)
                        guard preferences.notifyWhenDone, record.kind == .revive || record.kind == .restore else { return }
                        readiness.notify(title: Self.notificationTitle(for: record), body: record.device)
                    }
                }
        }
        .defaultSize(width: 1040, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(engine: engine, preferences: preferences, updater: updater, navigation: navigation)
        }

        Settings {
            SettingsView()
                .environment(engine)
                .environment(readiness)
                .environment(preferences)
                .environment(updater)
                .environment(navigation)
                .language(preferences.language)
        }
    }
}

extension MacDFUStudioApp {
    /// "Restore complete", "Revive failed"… for the notification that tells an absent user how it went.
    static func notificationTitle(for record: OperationRecord) -> String {
        switch (record.kind, record.outcome) {
        case (.restore, .success): String(localized: "Restore complete.")
        case (.restore, .failure): String(localized: "Restore failed.")
        case (.revive, .success): String(localized: "Revive complete.")
        case (.revive, .failure): String(localized: "Revive failed.")
        default: String(localized: "Stopped.")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var engine: DiagnosticsEngine? {
        didSet { deliverPendingFirmware() }
    }
    weak var navigation: Navigation?
    /// A restore image the app was asked to open before its window existed.
    private var pendingFirmware: URL?

    /// A restore image opened with this app — from the Finder, or handed over by IPSW Downloader Plus.
    ///
    /// It is taken as the file to restore from, exactly as if it had been dropped on the window, and
    /// when a Mac that can take it is on the cable the restore sheet opens with it chosen. Nothing is
    /// erased here: the sheet's confirmation is still the only thing that starts a restore.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let firmware = urls.first(where: DiagnosticsEngine.isFirmwareFile) else { return }
        pendingFirmware = firmware
        deliverPendingFirmware()
    }

    private func deliverPendingFirmware() {
        guard let engine, let firmware = pendingFirmware else { return }
        pendingFirmware = nil
        NSApplication.shared.activate()
        guard engine.demo == nil, !engine.isBusy else { return }
        engine.firmwareURL = firmware
        engine.report(.info, "Firmware ready: \(firmware.lastPathComponent)")
        navigation?.section = .connect
        if let device = engine.focusedDevice, device.state.acceptsFirmware, !device.isIntelT2 {
            navigation?.showsRestoreSheet = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A binary run straight from a build folder has no bundle to tell the system it is a regular app.
        if Bundle.main.bundleURL.pathExtension != "app" {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Quitting — or closing the window — in the middle of a firmware write deserves a second thought.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard engine?.operation?.canStop == true else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "A Mac is being revived or restored.")
        alert.informativeText = String(localized: "A Mac stopped half-way may not start until it is restored.")
        alert.addButton(withTitle: String(localized: "Keep Going"))
        alert.addButton(withTitle: String(localized: "Quit Anyway"))
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
