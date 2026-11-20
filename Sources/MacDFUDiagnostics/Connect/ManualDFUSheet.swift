import SwiftUI

/// How to put a Mac into DFU with its own buttons — for when the one-click command is not answered.
///
/// The key combinations and timings are Apple's, from "How to revive or restore Mac firmware"
/// (support article 108900).
struct ManualDFUSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .laptop

    private enum Kind: Hashable {
        case laptop
        case desktop
    }

    private static let appleGuide = URL(string: "https://support.apple.com/108900")!

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.standard) {
            HStack {
                Text("Enter DFU by Hand")
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker("Kind", selection: $kind) {
                    Label("Laptop", systemImage: "macbook").tag(Kind.laptop)
                    Label("Desktop", systemImage: "desktopcomputer").tag(Kind.desktop)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: Metrics.compact) {
                switch kind {
                case .laptop: laptopSteps
                case .desktop: desktopSteps
                }
            }
            .frame(minHeight: 230, alignment: .top)

            Divider()

            HStack {
                Link(destination: Self.appleGuide) {
                    Label("Apple's guide", systemImage: "arrow.up.right")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Metrics.roomy)
        .frame(width: 480)
        .animation(.smooth(duration: 0.25), value: kind)
    }

    @ViewBuilder
    private var laptopSteps: some View {
        GuideStep(1) { Text("Hold the power button for up to 10 seconds, until the Mac turns off.") }
        GuideStep(2) {
            VStack(alignment: .leading, spacing: Metrics.tight) {
                Text("Press and release the power button, then at once hold all four:")
                HStack(spacing: Metrics.tight) {
                    Keycap("⌃", caption: "left control")
                    Keycap("⌥", caption: "left option")
                    Keycap("⇧", caption: "right shift")
                    Keycap("⏻", caption: "power")
                }
            }
        }
        GuideStep(3) {
            VStack(alignment: .leading, spacing: Metrics.hairline) {
                Text("Apple silicon: after about 10 seconds release the three keys, and keep holding power for up to 10 more.")
                Text("Intel with T2: hold all four for about 3 seconds.")
                    .foregroundStyle(.secondary)
            }
        }
        GuideStep(4) { Text("The screen stays blank, and the Mac appears here.") }
    }

    @ViewBuilder
    private var desktopSteps: some View {
        GuideStep(1) { Text("Unplug the Mac from power.") }
        GuideStep(2) {
            HStack(spacing: Metrics.tight) {
                Text("Hold the power button and plug the Mac back in.")
                Keycap("⏻")
            }
        }
        GuideStep(3) { Text("Keep holding for up to 10 seconds.") }
        GuideStep(4) { Text("The screen stays blank, and the Mac appears here.") }
    }
}
