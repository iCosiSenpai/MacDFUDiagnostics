import SwiftUI

/// Which decorative effects are on. Computed once at the root from the user's settings and the system's
/// accessibility settings, then read from the environment by anything that moves or glows.
struct Effects: Equatable, Sendable {
    /// GPU shaders: the liquid background, the ripple, the shimmer.
    var shaders = true
    /// Animations, transitions, symbol effects, hover reactions.
    var motion = true
}

extension EnvironmentValues {
    @Entry var effects = Effects()
}

// MARK: - Shaders

/// The compiled Metal library that ships in the app bundle. Absent when the app is run straight from a
/// build folder, in which case every shader effect quietly turns into its plain equivalent.
enum AppShaders {
    static let library: ShaderLibrary? = {
        guard let url = Bundle.main.url(forResource: "Effects", withExtension: "metallib") else { return nil }
        return ShaderLibrary(url: url)
    }()
}

// MARK: - Motion helpers

private struct HoverLift: ViewModifier {
    @Environment(\.effects) private var effects
    @State private var isHovered = false
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && effects.motion ? scale : 1)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

private struct SymbolBounce<Value: Equatable>: ViewModifier {
    @Environment(\.effects) private var effects
    let value: Value

    func body(content: Content) -> some View {
        if effects.motion {
            content.symbolEffect(.bounce, value: value)
        } else {
            content
        }
    }
}

private struct SymbolPulse: ViewModifier {
    @Environment(\.effects) private var effects
    let isActive: Bool

    func body(content: Content) -> some View {
        content.symbolEffect(.pulse, isActive: isActive && effects.motion)
    }
}

/// A band of light sweeping across the content while `isActive`.
private struct Shimmer: ViewModifier {
    @Environment(\.effects) private var effects
    @Environment(\.appearsActive) private var appearsActive
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive, effects.shaders, let library = AppShaders.library {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !appearsActive)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600)
                content.visualEffect { view, proxy in
                    view.colorEffect(library.shimmer(.float2(proxy.size), .float(time)))
                }
            }
        } else {
            content
        }
    }
}

/// Re-applies the language chosen in Settings. Sheets and popovers are hosted in windows of their own and
/// do not inherit the locale of the view that presents them.
private struct ChosenLanguage: ViewModifier {
    @Environment(Preferences.self) private var preferences

    func body(content: Content) -> some View {
        content.language(preferences.language)
    }
}

extension View {
    /// For the root of a sheet or popover: shows it in the language picked in Settings.
    func chosenLanguage() -> some View {
        modifier(ChosenLanguage())
    }

    /// Shows the interface in the language picked in Settings; does nothing when that is "System".
    @ViewBuilder
    func language(_ choice: LanguageChoice) -> some View {
        if let locale = choice.locale {
            environment(\.locale, locale)
        } else {
            self
        }
    }

    /// Grows slightly under the pointer.
    func hoverLift(_ scale: CGFloat = 1.03) -> some View {
        modifier(HoverLift(scale: scale))
    }

    /// Bounces contained symbols when `value` changes.
    func symbolBounce(on value: some Equatable) -> some View {
        modifier(SymbolBounce(value: value))
    }

    /// Pulses contained symbols while `isActive`.
    func symbolPulse(_ isActive: Bool) -> some View {
        modifier(SymbolPulse(isActive: isActive))
    }

    func shimmer(_ isActive: Bool) -> some View {
        modifier(Shimmer(isActive: isActive))
    }
}
