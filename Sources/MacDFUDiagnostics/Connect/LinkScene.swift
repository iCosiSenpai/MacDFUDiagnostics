import SwiftUI

/// This Mac — cable — the other Mac.
struct LinkScene: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation

    private let tileSize = CGSize(width: 140, height: 118)

    var body: some View {
        let device = engine.focusedDevice
        let tint = device?.state.tint ?? .secondary

        HStack(alignment: .top, spacing: 0) {
            DeviceNode(
                symbol: engine.host.model?.family.symbol ?? "macbook",
                title: Text("This Mac"),
                tint: .accentColor,
                tileSize: tileSize
            ) {
                Text(verbatim: engine.host.name)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            CableView(
                tint: engine.isBusy ? .blue : tint,
                isLinked: device != nil,
                operation: engine.operation,
                symbol: device?.state.symbol ?? "cable.connector"
            )
            .frame(minWidth: 80, idealWidth: 220, maxWidth: 280)
            .frame(height: tileSize.height)

            if let device {
                Button {
                    navigation.inspectorTab = .device
                    navigation.showsInspector = true
                } label: {
                    DeviceNode(
                        symbol: device.symbol, title: Text("Other Mac"), tint: tint, tileSize: tileSize,
                        pingTrigger: engine.arrivals, progress: engine.operation?.progress
                    ) {
                        StatusChip(text: device.state.label, tint: tint)
                    }
                }
                .buttonStyle(.plain)
                .hoverLift()
                .help("Show details")
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .id(device.id)
                .overlay(alignment: .bottom) {
                    if engine.devices.count > 1 {
                        deviceSwitcher
                            .offset(y: 34)
                    }
                }
            } else {
                DeviceNode(symbol: "plus", title: Text("Other Mac"), tint: .secondary, tileSize: tileSize, isPlaceholder: true) {
                    Text("Not connected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: device?.id)
        .animation(.smooth(duration: 0.3), value: engine.operation?.kind)
    }

    private var deviceSwitcher: some View {
        @Bindable var engine = engine
        return Picker("Device", selection: Binding(
            get: { engine.focusedDevice?.id },
            set: { engine.focusedDeviceID = $0 }
        )) {
            ForEach(engine.devices) { device in
                Text(verbatim: device.title).tag(Optional(device.id))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }
}

/// A Mac, drawn as a glass tile with its symbol, its name and whatever belongs under the name.
private struct DeviceNode<Caption: View>: View {
    let symbol: String
    let title: Text
    let tint: Color
    let tileSize: CGSize
    var isPlaceholder = false
    var pingTrigger = 0
    /// While firmware is being written, the tile's edge fills up with it.
    var progress: Double?
    @ViewBuilder var caption: Caption

    var body: some View {
        VStack(spacing: Metrics.tight) {
            tile
                .padding(.bottom, Metrics.hairline)
            title
                .font(.headline)
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            caption
        }
        .frame(width: 210)
    }

    @ViewBuilder
    private var tile: some View {
        if isPlaceholder {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
                .frame(width: tileSize.width, height: tileSize.height)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                }
        } else {
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: tileSize.width, height: tileSize.height)
                .glassSurface(cornerRadius: Metrics.tileRadius, tint: tint.opacity(0.14))
                .background { Ping(trigger: pingTrigger, tint: tint) }
                .overlay {
                    if let progress {
                        RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                            .trim(from: 0, to: max(0.01, min(progress, 1)))
                            .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .shadow(color: .blue.opacity(0.7), radius: 5)
                            .animation(.smooth, value: progress)
                            .transition(.opacity)
                    }
                }
        }
    }
}

/// A ring that expands and fades from behind a tile when its Mac arrives.
private struct Ping: View {
    let trigger: Int
    let tint: Color
    @Environment(\.effects) private var effects

    var body: some View {
        if effects.motion {
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .stroke(tint, lineWidth: 2)
                .keyframeAnimator(initialValue: PingFrame(), trigger: trigger) { ring, frame in
                    ring.scaleEffect(frame.scale).opacity(frame.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(1)
                        CubicKeyframe(1.55, duration: 0.9)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0.7)
                        CubicKeyframe(0, duration: 0.9)
                    }
                }
        }
    }

    private struct PingFrame {
        var scale = 1.0
        var opacity = 0.0
    }
}

// MARK: - Cable

/// The line between the two Macs: dashed when nothing is detected, alive with travelling light when a
/// Mac is there, and wearing a progress ring while work is under way.
private struct CableView: View {
    let tint: Color
    let isLinked: Bool
    let operation: Operation?
    let symbol: String

    @Environment(\.effects) private var effects

    var body: some View {
        ZStack {
            if isLinked {
                Capsule()
                    .fill(tint.opacity(0.32))
                    .frame(height: 3)
                // Light travels down the cable only while something is being sent — so it means
                // something, and an idle window stays idle.
                if effects.motion, operation != nil {
                    TravellingLights(tint: tint)
                        .transition(.opacity)
                }
            } else {
                Line()
                    .stroke(.tertiary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 9]))
            }
            orb
        }
        .padding(.horizontal, Metrics.tight)
        .accessibilityHidden(true)
    }

    private var orb: some View {
        ZStack {
            if let operation {
                ProgressRing(progress: operation.progress, tint: tint)
                    .padding(3)
            } else {
                Image(systemName: isLinked ? symbol : "cable.connector")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isLinked ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                }
        }
        .frame(width: 42, height: 42)
        .glassCapsule(tint: isLinked ? tint.opacity(0.12) : nil)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Points of light running along the cable, from this Mac to the other.
///
/// Each one is a plain view whose position is animated once and repeats; a gradient mask fades them in
/// at one end and out at the other. They exist only while an operation runs.
private struct TravellingLights: View {
    let tint: Color

    private static let count = 3
    private static let duration = 1.8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(0..<Self.count, id: \.self) { index in
                    Light(tint: tint, distance: proxy.size.width, duration: Self.duration, delayFraction: Double(index) / Double(Self.count))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .mask {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                            .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        }
    }

    private struct Light: View {
        let tint: Color
        let distance: CGFloat
        let duration: Double
        let delayFraction: Double

        @State private var hasStarted = false

        var body: some View {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint, radius: 5)
                .offset(x: hasStarted ? distance : -6)
                .onAppear {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false).delay(-duration * delayFraction)) {
                        hasStarted = true
                    }
                }
        }
    }
}
