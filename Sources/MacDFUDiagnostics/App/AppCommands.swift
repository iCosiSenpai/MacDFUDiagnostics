import SwiftUI

/// The menu bar. Everything the window can do is here too, with a keyboard shortcut where it earns one.
struct AppCommands: Commands {
    let engine: DiagnosticsEngine
    let preferences: Preferences
    let updater: UpdateManager
    let navigation: Navigation

    @Environment(\.openSettings) private var openSettings

    private static let dfuGuide = URL(string: "https://support.apple.com/120694")!
    private static let reviveGuide = URL(string: "https://support.apple.com/108900")!
    private static let project = URL(string: "https://github.com/iCosiSenpai/MacDFUDiagnostics")!

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                navigation.settingsTab = .updates
                openSettings()
                Task { await updater.check() }
            }
        }

        // A single-window app has no "New Window".
        CommandGroup(replacing: .newItem) {}

        SidebarCommands()

        CommandGroup(after: .sidebar) {
            Button(navigation.showsInspector ? "Hide Inspector" : "Show Inspector") {
                navigation.showsInspector.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Divider()

            Button("Connect") { navigation.section = .connect }
                .keyboardShortcut("1")
            Button("Disks") { navigation.section = .disks }
                .keyboardShortcut("2")
            Button("Macs") { navigation.section = .macs }
                .keyboardShortcut("3")

            Divider()

            Toggle("Reduce Effects", isOn: Binding(
                get: { preferences.allEffectsOff },
                set: { preferences.setAllEffects(!$0) }
            ))
            .keyboardShortcut("e", modifiers: [.command, .control])

            Divider()
        }

        CommandMenu("Device") {
            Button("Enter DFU") {
                Task { await engine.send(.dfu) }
            }
            .keyboardShortcut("d")
            .disabled(engine.isBusy)

            Button("Revive") {
                if let device = engine.focusedDevice {
                    Task { await engine.revive(device) }
                }
            }
            .disabled(!canWriteFirmware)

            Button("Restore…") {
                navigation.section = .connect
                navigation.showsRestoreSheet = true
            }
            .disabled(!canWriteFirmware)

            Divider()

            DeviceMenuItems()
                .environment(engine)
                .environment(preferences)
                .environment(navigation)

            Divider()

            Button("Refresh") {
                engine.refreshHardware()
                Task { await engine.refreshDisks() }
            }
            .keyboardShortcut("r")
        }

        CommandGroup(replacing: .help) {
            Button("Find the DFU Port") {
                navigation.section = .connect
                navigation.showsPortGuide = true
            }
            Divider()
            Link("Apple: DFU Ports", destination: Self.dfuGuide)
            Link("Apple: Revive or Restore a Mac", destination: Self.reviveGuide)
            Link("Mac DFU Studio on GitHub", destination: Self.project)
        }
    }

    private var canWriteFirmware: Bool {
        !engine.isBusy && engine.focusedDevice?.state.acceptsFirmware == true && engine.cfgutilPath != nil
    }
}
