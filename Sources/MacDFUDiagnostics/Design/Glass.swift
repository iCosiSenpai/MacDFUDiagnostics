import SwiftUI

// Liquid Glass where the system has it (macOS 26 and later), a material with a hairline edge before.
// Screens use these wrappers and never branch on the OS version themselves.

extension View {
    /// A glass panel in a rounded rectangle.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = Metrics.cardRadius, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill((tint ?? .clear).opacity(0.5))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    }
            }
        }
    }

    /// A glass pill.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: .capsule)
        } else {
            background {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay { Capsule().fill((tint ?? .clear).opacity(0.5)) }
                    .overlay { Capsule().strokeBorder(.separator, lineWidth: 0.5) }
            }
        }
    }

    /// The one main action on a screen.
    @ViewBuilder
    func primaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Actions that sit beside the main one.
    @ViewBuilder
    func secondaryActionStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Lets a full-bleed background continue, blurred, underneath the floating sidebar.
    @ViewBuilder
    func extendedUnderSidebar() -> some View {
        if #available(macOS 26, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
    }
}

/// Groups glass elements so they are lit as one and can merge as they move.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = Metrics.compact
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
