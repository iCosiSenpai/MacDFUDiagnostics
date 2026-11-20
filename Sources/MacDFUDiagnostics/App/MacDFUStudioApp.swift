import SwiftUI

@main
struct MacDFUStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var engine = DiagnosticsEngine(demo: LaunchOptions.demo)
    @State private var preferences = Preferences()
    @State private var updater = UpdateManager()
    @State private var navigation = Navigation()

    var body: some Scene {
        // One window: the app drives one piece of hardware, and two windows would only disagree.
        Window("Mac DFU Studio", id: "main") {
            RootView()
                .frame(minWidth: 820, minHeight: 560)
                .environment(engine)
                .environment(preferences)
                .environment(updater)
                .environment(navigation)
                .language(preferences.language)
                .onAppear {
                    appDelegate.engine = engine
                    preferences.applyAppearance()
                }
        }
        .defaultSize(width: 1040, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(engine: engine, preferences: preferences, updater: updater, navigation: navigation)
        }

        Settings {
            SettingsView()
                .environment(preferences)
                .environment(updater)
                .environment(navigation)
                .language(preferences.language)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var engine: DiagnosticsEngine?

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
