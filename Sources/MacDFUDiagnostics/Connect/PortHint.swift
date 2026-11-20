import SwiftUI

/// The small "Which port?" control at the bottom of the Connect screen, and the guide it opens.
struct PortHint: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        Button {
            navigation.showsPortGuide.toggle()
        } label: {
            HStack(spacing: Metrics.compact) {
                if let layout = engine.host.model?.port {
                    PortDiagram(layout: layout, scale: 0.8)
                }
                Text("Which port?")
                    .font(.callout.weight(.medium))
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Metrics.standard)
            .padding(.vertical, Metrics.tight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassCapsule(interactive: true)
        .hoverLift(1.02)
        .popover(isPresented: $navigation.showsPortGuide, arrowEdge: .bottom) {
            PortGuide()
                .chosenLanguage()
        }
        .task {
            // A popover cannot open before its anchor is on screen.
            if LaunchOptions.sheet == "ports" {
                try? await Task.sleep(for: .seconds(1))
                navigation.showsPortGuide = true
            }
        }
    }
}

private struct PortGuide: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation

    private static let appleGuide = URL(string: "https://support.apple.com/120694")!

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.standard) {
            if let host = engine.host.model {
                row(title: "This Mac", name: host.name, layout: host.port)
            }
            if let target = engine.focusedDevice?.model {
                Divider()
                row(title: "Other Mac", name: target.name, layout: target.port)
            }

            Divider()

            Label {
                Text("Use a USB-C charge cable. Not Thunderbolt, no hub.")
            } icon: {
                Image(systemName: "cable.connector")
                    .foregroundStyle(.tint)
            }
            .font(.callout)

            HStack {
                Button("All Macs") {
                    navigation.showsPortGuide = false
                    navigation.section = .macs
                }
                Spacer()
                Link(destination: Self.appleGuide) {
                    Label("Apple's guide", systemImage: "arrow.up.right")
                }
            }
            .font(.callout)
        }
        .padding(Metrics.standard)
        .frame(width: 320)
    }

    private func row(title: LocalizedStringKey, name: String, layout: DFUPortLayout) -> some View {
        VStack(alignment: .leading, spacing: Metrics.tight) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(verbatim: name)
                .font(.headline)
            PortDiagram(layout: layout, scale: 1.25, isAnimated: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Metrics.hairline)
            Text(layout.caption)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
