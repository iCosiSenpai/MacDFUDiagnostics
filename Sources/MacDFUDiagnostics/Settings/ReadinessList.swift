import SwiftUI

/// The checklist of what the app needs, each line with its state and, where there is one, its fix.
/// Shown in Settings › Advanced and in the welcome sheet.
struct ReadinessList: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Readiness.self) private var readiness
    @Environment(\.openURL) private var openURL

    var body: some View {
        notifications
        administrator
        helper
        port
        configurator
        internet
    }

    @ViewBuilder
    private var notifications: some View {
        switch readiness.notifications {
        case .allowed:
            ReadinessRow("Notifications", state: .ready, detail: "You are told when a revive or a restore ends.")
        case .denied:
            ReadinessRow("Notifications", state: .attention, detail: "Turned off for this app in System Settings.") {
                Button("Open Settings") { readiness.openNotificationSettings() }
            }
        case .notAsked, .unknown:
            ReadinessRow("Notifications", state: .attention, detail: "Allow them to be told when a revive or a restore ends.") {
                Button("Allow") {
                    Task { await readiness.requestNotifications() }
                }
            }
        case .unavailable:
            ReadinessRow("Notifications", state: .neutral, detail: "Not available in this build.")
        }
    }

    @ViewBuilder
    private var administrator: some View {
        if readiness.isAdministrator {
            ReadinessRow("Administrator", state: .ready, detail: "macOS asks for your password when a command is sent to the port.")
        } else {
            ReadinessRow("Administrator", state: .problem, detail: "This account is not an administrator. Commands need an administrator's name and password.")
        }
    }

    @ViewBuilder
    private var helper: some View {
        switch readiness.helper {
        case .verified:
            ReadinessRow("USB-C helper", state: .ready, detail: "Signed by the developer and verified.")
        case .development:
            ReadinessRow("USB-C helper", state: .neutral, detail: "Development build: the signature is not checked.")
        case .missing, .rejected:
            ReadinessRow("USB-C helper", state: .problem, detail: "Missing or damaged. Reinstall the app.")
        }
    }

    @ViewBuilder
    private var port: some View {
        if !engine.host.isAppleSilicon {
            ReadinessRow("DFU port", state: .problem, detail: "Sending DFU requests needs a Mac with Apple silicon.")
        } else if engine.ports.contains(where: \.isDFUCapable) {
            ReadinessRow("DFU port", state: .ready, detail: "This Mac has a port that can send DFU requests.")
        } else {
            ReadinessRow("DFU port", state: .attention, detail: "No port that can send DFU requests was found.")
        }
    }

    @ViewBuilder
    private var configurator: some View {
        if engine.cfgutilPath != nil {
            ReadinessRow("Apple Configurator", state: .ready, detail: "Installed. Revive and restore are available.")
        } else {
            ReadinessRow("Apple Configurator", state: .attention, detail: "Not installed. Only reviving and restoring need it.") {
                Button("Get") { openURL(DiagnosticsEngine.configuratorURL) }
            }
        }
    }

    @ViewBuilder
    private var internet: some View {
        if readiness.isOnline {
            ReadinessRow("Internet", state: .ready, detail: "Connected. Firmware is downloaded from Apple.")
        } else {
            ReadinessRow("Internet", state: .attention, detail: "Offline. Reviving and restoring download firmware from Apple.")
        }
    }
}

/// One line of the checklist.
private struct ReadinessRow<Action: View>: View {
    enum State {
        case ready
        case attention
        case problem
        case neutral

        var symbol: String {
            switch self {
            case .ready: "checkmark.circle.fill"
            case .attention: "exclamationmark.circle.fill"
            case .problem: "xmark.octagon.fill"
            case .neutral: "minus.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .ready: .green
            case .attention: .orange
            case .problem: .red
            case .neutral: .secondary
            }
        }
    }

    let title: LocalizedStringKey
    let state: State
    let detail: LocalizedStringKey
    @ViewBuilder var action: Action

    init(_ title: LocalizedStringKey, state: State, detail: LocalizedStringKey, @ViewBuilder action: () -> Action) {
        self.title = title
        self.state = state
        self.detail = detail
        self.action = action()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.compact) {
            Image(systemName: state.symbol)
                .foregroundStyle(state.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Metrics.tight)
            action
                .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }
}

extension ReadinessRow where Action == EmptyView {
    init(_ title: LocalizedStringKey, state: State, detail: LocalizedStringKey) {
        self.init(title, state: state, detail: detail) { EmptyView() }
    }
}
