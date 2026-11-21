import SwiftUI

/// The menu bar. Everything the window can do is here too, with a keyboard shortcut where it earns one.
struct AppCommands: Commands {
    let engine: DiagnosticsEngine
    let preferences: Preferences
    let updater: UpdateManager
    let navigation: Navigation

    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Mac DFU Studio") {
                navigation.settingsTab = .about
                openSettings()
            }
        }

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
            Link("Apple: DFU Ports", destination: Links.dfuGuide)
            Link("Apple: Revive or Restore a Mac", destination: Links.reviveGuide)
            Divider()
            Link("Mac DFU Studio Website", destination: Links.website)
            Link("Mac DFU Studio on GitHub", destination: Links.project)
            Link("Report a Problem", destination: Links.issues)
            Divider()
            Link("Donate with PayPal", destination: Links.payPal)
            Link("Buy Me a Coffee", destination: Links.buyMeACoffee)
        }
    }

    private var canWriteFirmware: Bool {
        !engine.isBusy && engine.focusedDevice?.state.acceptsFirmware == true && engine.cfgutilPath != nil
    }
}
