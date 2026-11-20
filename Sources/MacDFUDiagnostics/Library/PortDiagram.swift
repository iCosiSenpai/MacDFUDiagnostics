import SwiftUI

/// Draws the face of a Mac that carries its DFU port, with that port lit.
///
/// The drawing is to scale only in spirit: what matters is which port, counted from which end.
struct PortDiagram: View {
    let layout: DFUPortLayout
    var tint: Color = .accentColor
    /// Scales the whole drawing; 1 suits a card, 1.6 a detail view.
    var scale: CGFloat = 1
    /// Whether the DFU port breathes. Reserved for the places a person is looking for it — a guide, a
    /// detail view — so that lists and always-visible controls stay still.
    var isAnimated = false

    @Environment(\.effects) private var effects

    var body: some View {
        Group {
            switch layout.face {
            case .left: sideView
            case .back: backView
            case .tower: towerView
            case .none: noPort
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(layout.caption))
    }

    // MARK: Faces

    /// A notebook seen from its left side: display hinge at the left, front edge at the right.
    private var sideView: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // The open lid, leaning back from the hinge.
            RoundedRectangle(cornerRadius: 1.5 * scale)
                .fill(.tertiary)
                .frame(width: 3 * scale, height: 34 * scale)
                .rotationEffect(.degrees(-14), anchor: .bottom)
                .offset(x: 5 * scale)

            HStack(spacing: 7 * scale) {
                if layout.hasMagSafe {
                    Capsule()
                        .strokeBorder(.tertiary, lineWidth: 1.2 * scale)
                        .frame(width: 20 * scale, height: 6 * scale)
                }
                ports
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12 * scale)
            .frame(width: 168 * scale, height: 16 * scale)
            .background(.quaternary, in: UnevenRoundedRectangle(
                topLeadingRadius: 3 * scale, bottomLeadingRadius: 8 * scale,
                bottomTrailingRadius: 8 * scale, topTrailingRadius: 3 * scale
            ))
        }
        .frame(height: 40 * scale, alignment: .bottom)
    }

    /// A desktop seen from behind.
    private var backView: some View {
        HStack(spacing: 8 * scale) {
            ports
        }
        .padding(.horizontal, 16 * scale)
        .frame(minWidth: 120 * scale)
        .frame(height: 34 * scale)
        .background(.quaternary, in: .rect(cornerRadius: 9 * scale))
    }

    /// The top of a Mac Pro tower: power button, then the two ports.
    private var towerView: some View {
        HStack(spacing: 10 * scale) {
            Image(systemName: "power")
                .font(.system(size: 9 * scale, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16 * scale, height: 16 * scale)
                .overlay { Circle().strokeBorder(.tertiary, lineWidth: 1.2 * scale) }
            ports
        }
        .padding(.horizontal, 16 * scale)
        .frame(height: 34 * scale)
        .background(.quaternary, in: .rect(cornerRadius: 9 * scale))
    }

    private var noPort: some View {
        Image(systemName: "cable.connector.slash")
            .font(.system(size: 20 * scale))
            .foregroundStyle(.tertiary)
            .frame(height: 34 * scale)
    }

    // MARK: Ports

    private var ports: some View {
        ForEach(1...max(layout.portCount, 1), id: \.self) { index in
            if index == layout.dfuIndex {
                Capsule()
                    .fill(tint)
                    .frame(width: 15 * scale, height: 6 * scale)
                    .shadow(color: tint.opacity(0.9), radius: 4 * scale)
                    .modifier(Beacon(isOn: isAnimated && effects.motion))
            } else {
                Capsule()
                    .strokeBorder(.secondary, lineWidth: 1.2 * scale)
                    .frame(width: 15 * scale, height: 6 * scale)
            }
        }
    }
}

/// A slow breathing glow that draws the eye to the DFU port.
private struct Beacon: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.phaseAnimator([1.0, 0.45]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        } else {
            content
        }
    }
}
