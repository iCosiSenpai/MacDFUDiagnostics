import SwiftUI

/// The window: sidebar, the selected screen, and the inspector.
struct RootView: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(UpdateManager.self) private var updater
    @Environment(Navigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var navigation = navigation
        let effects = Effects(
            shaders: preferences.shaderEffects && !reduceMotion,
            motion: preferences.motionEffects && !reduceMotion
        )

        NavigationSplitView {
            Sidebar()
        } detail: {
            Group {
                switch navigation.section {
                case .connect: ConnectView()
                case .disks: DisksView()
                case .macs: LibraryView()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if engine.demo != nil {
                    StatusChip(text: "Demo", tint: .orange, symbol: "theatermasks.fill")
                        .padding(Metrics.compact)
                        .help("Simulated hardware. Nothing real is touched.")
                }
            }
        }
        .inspector(isPresented: $navigation.showsInspector) {
            InspectorView()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
        .sheet(item: updateBinding) { release in
            UpdateSheet(release: release)
                .chosenLanguage()
        }
        .environment(\.effects, effects)
        // With motion off, nothing below this point animates: explicit and implicit animations alike.
        .transaction { transaction in
            if !effects.motion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .sensoryFeedback(.levelChange, trigger: engine.arrivals)
        .onChange(of: engine.arrivals) {
            if preferences.sounds, engine.demo == nil {
                NSSound(named: "Glass")?.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            engine.refreshHardware()
        }
        .task {
            engine.start()
            switch LaunchOptions.sheet {
            case "update":
                updater.presentSample()
            case "settings", "effects", "advanced", "updates":
                navigation.settingsTab = SettingsTab(rawValue: LaunchOptions.sheet ?? "") ?? .general
                openSettings()
            default:
                if updater.canSelfUpdate, engine.demo == nil {
                    await updater.check(quietly: true)
                }
            }
        }
    }

    /// The update sheet waits its turn: it never appears on top of work in progress.
    private var updateBinding: Binding<AppRelease?> {
        Binding(
            get: { engine.isBusy ? nil : updater.pendingRelease },
            set: { _ in }
        )
    }
}

extension AppRelease: Identifiable {
    var id: String { version }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation

    var body: some View {
        List(selection: selection) {
            ForEach(AppSection.allCases) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbol)
                }
                .badge(badge(for: section))
                .tag(section)
            }
        }
        .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
    }

    private var selection: Binding<AppSection?> {
        Binding(
            get: { navigation.section },
            set: { if let section = $0 { navigation.section = section } }
        )
    }

    private func badge(for section: AppSection) -> Int {
        switch section {
        case .connect: engine.devices.count
        case .disks: engine.disks.count
        case .macs: 0
        }
    }
}
