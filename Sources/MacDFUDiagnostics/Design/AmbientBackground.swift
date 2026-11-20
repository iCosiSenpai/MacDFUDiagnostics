import SwiftUI

/// The living backdrop of the Connect screen: soft pools of the current state's colour, drawn and slowly
/// moved by a Metal shader, with a ripple when something happens.
///
/// It only animates while the window is active, at 15 frames a second and a quarter of the resolution,
/// and collapses to a still gradient when shaders are switched off — so it costs little when it runs and
/// nothing when nobody is looking.
struct AmbientBackground: View {
    var tint: Color
    /// A stronger current while work is in progress.
    var isEnergetic = false
    /// Changes whenever a ripple should play.
    var rippleTrigger = 0
    /// Where the ripple starts, in unit coordinates.
    var rippleOrigin = UnitPoint(x: 0.7, y: 0.4)

    @Environment(\.effects) private var effects
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var epoch = Date.now
    /// The colour being faded out of, and when the fade began.
    @State private var previousTint: Color?
    @State private var tintChanged = Date.distantPast

    /// The backdrop is all soft gradients, so it is drawn at a fraction of the window's size and
    /// stretched: a sixteenth of the pixels to shade and to keep in memory, with no visible difference.
    private static let downscale: CGFloat = 4
    /// Slow drift does not need a high frame rate.
    private static let frameInterval = 1.0 / 15.0
    private static let fadeDuration = 1.2

    var body: some View {
        if reduceTransparency {
            Rectangle().fill(.background)
        } else if effects.shaders, let library = AppShaders.library {
            GeometryReader { proxy in
                let scale = Self.downscale
                TimelineView(.animation(minimumInterval: Self.frameInterval, paused: !appearsActive)) { timeline in
                    let time = timeline.date.timeIntervalSince(epoch)
                    let blend = min(1, timeline.date.timeIntervalSince(tintChanged) / Self.fadeDuration)
                    let from = previousTint ?? tint
                    let energy: Double = isEnergetic ? 1 : 0
                    Rectangle()
                        .frame(width: max(1, proxy.size.width / scale), height: max(1, proxy.size.height / scale))
                        .visualEffect { [tint] view, small in
                            view.colorEffect(library.aurora(
                                .float2(small.size), .float(time),
                                .color(Color(nsColor: .windowBackgroundColor)),
                                .color(from), .color(tint), .float(blend),
                                .color(.blue), .float(energy)
                            ))
                        }
                        .modifier(Ripple(trigger: rippleTrigger, origin: rippleOrigin, library: library, downscale: scale))
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
            }
            .onChange(of: tint) { old, _ in
                previousTint = old
                tintChanged = .now
            }
        } else {
            gradient
        }
    }

    private var gradient: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                base, wash(tint, 0.84), base,
                wash(.blue, 0.88), wash(tint, 0.62), wash(tint, 0.8),
                base, wash(.teal, 0.9), base,
            ]
        )
        .animation(.smooth(duration: 1.2), value: tint)
    }

    private var base: Color { Color(nsColor: .windowBackgroundColor) }

    /// A colour mostly dissolved into the window background, so it reads as light rather than paint.
    private func wash(_ color: Color, _ amount: Double) -> Color {
        color.mix(with: base, by: amount)
    }
}

/// Plays the ripple shader once each time `trigger` changes.
private struct Ripple: ViewModifier {
    let trigger: Int
    let origin: UnitPoint
    let library: ShaderLibrary
    /// The content is drawn this many times smaller than it is shown; distances shrink with it.
    let downscale: CGFloat

    private let duration = 2.4

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: duration, trigger: trigger) { view, elapsed in
            view.visualEffect { [library, origin, duration, downscale] effect, proxy in
                effect.layerEffect(
                    library.ripple(
                        .float2(CGPoint(x: proxy.size.width * origin.x, y: proxy.size.height * origin.y)),
                        .float(elapsed),
                        .float(14 / downscale),   // amplitude, in points
                        .float(13),               // frequency
                        .float(4.5),              // decay
                        .float(820 / downscale)   // speed, points per second
                    ),
                    maxSampleOffset: CGSize(width: 14 / downscale, height: 14 / downscale),
                    isEnabled: elapsed > 0 && elapsed < duration
                )
            }
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(duration, duration: duration)
        }
    }
}
