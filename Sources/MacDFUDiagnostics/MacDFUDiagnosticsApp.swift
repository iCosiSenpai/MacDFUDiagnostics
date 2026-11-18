import SwiftUI
import AppKit

@main
struct MacDFUDiagnosticsApp: App {
    @State private var engine = DiagnosticsEngine()
    @State private var prefs = AppPreferences()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Mac DFU Studio — Apple Silicon & Intel T2 / TDM") {
            MainRootView(engine: engine, prefs: prefs)
                .frame(minWidth: 1020, minHeight: 680)
                .onAppear {
                    prefs.theme.applyToNSApp()
                    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                       let img = NSImage(contentsOf: iconURL) {
                        NSApplication.shared.applicationIconImage = img
                    }
                    engine.startMonitoring()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    engine.stopMonitoring()
                }
        }
    }
}
