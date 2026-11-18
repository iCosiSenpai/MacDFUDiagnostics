import SwiftUI
import AppKit

@main
struct MacDFUDiagnosticsApp: App {
    @State private var engine = DiagnosticsEngine()
    @State private var prefs = AppPreferences()
    @State private var updater = UpdateManager()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Mac DFU Studio — Apple Silicon & Intel T2 / TDM") {
            MainRootView(engine: engine, prefs: prefs, updater: updater)
                .frame(minWidth: 860, minHeight: 620)
                .onAppear {
                    engine.preferences = prefs
                    engine.scanDefaultIPSWFolder()
                    prefs.theme.applyToNSApp()
                    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                       let img = NSImage(contentsOf: iconURL) {
                        NSApplication.shared.applicationIconImage = img
                    }
                    engine.startMonitoring()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    Task {
                        await updater.checkForUpdates(silentIfUpToDate: true)
                    }
                }
                .onDisappear {
                    engine.stopMonitoring()
                }
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(prefs.tr("Impostazioni…", "Settings…")) {
                    NotificationCenter.default.post(name: .openAppSettingsSection, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)

                Button(prefs.tr("Verifica Aggiornamenti…", "Check for Updates…")) {
                    NotificationCenter.default.post(name: .openAppSettingsSection, object: nil)
                    Task {
                        await updater.checkForUpdates(silentIfUpToDate: false)
                    }
                }
            }
        }
    }
}
