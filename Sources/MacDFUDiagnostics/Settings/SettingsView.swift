import SwiftUI

enum SettingsTab: String, Hashable {
    case general
    case effects
    case advanced
    case updates
    case about
}

/// The Settings window (⌘,).
struct SettingsView: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.settingsTab) {
            Tab("General", systemImage: "gearshape", value: SettingsTab.general) {
                GeneralSettings()
            }
            Tab("Effects", systemImage: "sparkles", value: SettingsTab.effects) {
                EffectsSettings()
            }
            Tab("Advanced", systemImage: "wrench.and.screwdriver", value: SettingsTab.advanced) {
                AdvancedSettings()
            }
            Tab("Updates", systemImage: "arrow.down.circle", value: SettingsTab.updates) {
                UpdateSettings()
            }
            Tab("About", systemImage: "info.circle", value: SettingsTab.about) {
                AboutSettings()
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettings: View {
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences

        Form {
            Section {
                Picker("Appearance", selection: $preferences.appearance) {
                    Label("Auto", systemImage: "circle.lefthalf.filled").tag(AppearanceChoice.system)
                    Label("Light", systemImage: "sun.max").tag(AppearanceChoice.light)
                    Label("Dark", systemImage: "moon").tag(AppearanceChoice.dark)
                }
                .pickerStyle(.segmented)

                Picker("Language", selection: $preferences.language) {
                    Text("System").tag(LanguageChoice.system)
                    Text(verbatim: "English").tag(LanguageChoice.english)
                    Text(verbatim: "Italiano").tag(LanguageChoice.italian)
                }
            } footer: {
                Text("Menus change language the next time the app opens.")
            }

            Section {
                Toggle("Sounds", isOn: $preferences.sounds)
                Toggle("Notify when a revive or a restore ends", isOn: $preferences.notifyWhenDone)
                Toggle("Keep this Mac awake", isOn: $preferences.keepAwake)
            } footer: {
                Text("Notifications appear only while the app is in the background. The Mac never sleeps during a revive or a restore.")
            }
        }
    }
}

private struct EffectsSettings: View {
    @Environment(Preferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var preferences = preferences

        Form {
            Section {
                preview
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Toggle("Animated background", isOn: $preferences.shaderEffects)
                Toggle("Motion", isOn: $preferences.motionEffects)
            } footer: {
                if reduceMotion {
                    Text("Reduce Motion is on in System Settings, so effects stay off.")
                } else {
                    Text("Effects pause whenever the window is in the background.")
                }
            }

            Section {
                Button(preferences.allEffectsOff ? "Turn On All Effects" : "Turn Off All Effects") {
                    preferences.setAllEffects(preferences.allEffectsOff)
                }
            }
        }
    }

    /// A live sample of what the two switches change.
    private var preview: some View {
        let effects = Effects(
            shaders: preferences.shaderEffects && !reduceMotion,
            motion: preferences.motionEffects && !reduceMotion
        )
        return ZStack {
            AmbientBackground(tint: .indigo)
            HStack(spacing: Metrics.standard) {
                Image(systemName: "macbook")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.indigo)
                    .frame(width: 72, height: 60)
                    .glassSurface(cornerRadius: 16, tint: .indigo.opacity(0.14))
                    .hoverLift(1.08)
                PortDiagram(layout: .left(1, of: 2, magSafe: true), tint: .indigo, isAnimated: true)
            }
        }
        .frame(height: 120)
        .clipShape(.rect(cornerRadius: Metrics.insetRadius))
        .environment(\.effects, effects)
        .accessibilityHidden(true)
    }
}

private struct AdvancedSettings: View {
    @Environment(Preferences.self) private var preferences
    @Environment(Readiness.self) private var readiness
    @State private var isConfirmingReset = false

    var body: some View {
        @Bindable var preferences = preferences

        Form {
            Section {
                ReadinessList()
            } header: {
                Text("Permissions and requirements")
            } footer: {
                Text("Notifications are the only consent macOS asks for. The administrator password is requested each time a command is sent.")
            }

            Section {
                Picker("Serial console speed", selection: $preferences.baudRate) {
                    ForEach(DiagnosticsEngine.baudRates, id: \.self) { rate in
                        Text(verbatim: "\(rate.formatted(.number.grouping(.never))) baud").tag(rate)
                    }
                }
            }

            Section {
                Button("Reset All Settings…") {
                    isConfirmingReset = true
                }
            }
        }
        .confirmationDialog("Reset all settings?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive) { preferences.resetToDefaults() }
        }
        .task { await readiness.refresh() }
    }
}

private struct UpdateSettings: View {
    @Environment(UpdateManager.self) private var updater

    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(verbatim: "\(updater.currentVersion) (\(updater.currentBuild))")
                        .monospacedDigit()
                }
                LabeledContent("Status") {
                    status
                }
            }

            Section {
                HStack {
                    Button("Check Now") {
                        Task { await updater.check() }
                    }
                    .disabled(updater.isWorking)
                    Spacer()
                    Link("All Releases", destination: UpdateManager.releasesPage)
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch updater.state {
        case .idle:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            ProgressView().controlSize(.small)
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .available(let release), .downloading(let release, _), .installing(let release):
            Text("Version \(release.version) available").foregroundStyle(.tint)
        case .failed(_, let message):
            Text(verbatim: message).foregroundStyle(.red).multilineTextAlignment(.trailing)
        }
    }
}
