import SwiftUI

/// Spacing and shape, on an 8-point grid. Every screen draws from here so they stay in step.
enum Metrics {
    static let hairline: CGFloat = 4
    static let tight: CGFloat = 8
    static let compact: CGFloat = 12
    static let standard: CGFloat = 16
    static let roomy: CGFloat = 24
    static let wide: CGFloat = 32

    /// Cards and panels.
    static let cardRadius: CGFloat = 20
    /// The large device tiles on the Connect screen.
    static let tileRadius: CGFloat = 30
    /// Small inset elements.
    static let insetRadius: CGFloat = 10
}

// MARK: - How each state looks and reads

extension TargetState {
    var label: LocalizedStringResource {
        switch self {
        case .dfu: "DFU"
        case .portDFU: "Port DFU"
        case .debugUSB: "Debug USB"
        case .recovery: "Recovery"
        case .wtf: "WTF mode"
        case .restoring: "Restoring"
        case .booted: "On"
        case .cableFault: "Cable problem"
        case .other: "Connected"
        }
    }

    var tint: Color {
        switch self {
        case .dfu: .indigo
        case .portDFU: .purple
        case .debugUSB: .teal
        case .recovery, .wtf: .orange
        case .restoring: .blue
        case .booted: .green
        case .cableFault: .red
        case .other: .gray
        }
    }

    var symbol: String {
        switch self {
        case .dfu, .portDFU: "bolt.fill"
        case .debugUSB: "ladybug"
        case .recovery, .wtf: "lifepreserver"
        case .restoring: "arrow.triangle.2.circlepath"
        case .booted: "power"
        case .cableFault: "exclamationmark.triangle.fill"
        case .other: "cable.connector"
        }
    }
}

extension TargetDevice {
    /// SF Symbol for the kind of Mac this is; a chip when the device is not a known Mac.
    var symbol: String {
        if state == .cableFault { return "cable.connector.slash" }
        return model?.family.symbol ?? "memorychip"
    }
}

extension LogLevel {
    var symbol: String {
        switch self {
        case .info: "circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failure: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }
}

extension MacArchitecture {
    var label: LocalizedStringResource {
        switch self {
        case .appleSilicon: "Apple silicon"
        case .intelT2: "Intel with T2"
        case .intelLegacy: "Intel, no T2"
        }
    }
}

extension DFUPortLayout {
    /// Where the DFU port is, in a few words.
    var caption: LocalizedStringResource {
        guard let dfuIndex else { return "No DFU port. Use Target Disk Mode." }
        switch face {
        case .left:
            if dfuIndex == 1 { return hasMagSafe ? "Left side, next to MagSafe" : "Left side, nearest the hinge" }
            return "Left side, nearest the front"
        case .back:
            if dfuIndex == 1 { return "Back, leftmost port" }
            if dfuIndex == portCount { return "Back, rightmost port" }
            return "Back, middle port"
        case .tower:
            return "Tower: top, farthest from the power button. Rack: front, nearest it."
        case .none:
            return "No DFU port. Use Target Disk Mode."
        }
    }
}

extension Operation.Kind {
    /// What is happening, as a headline.
    var headline: LocalizedStringResource {
        switch self {
        case .vdm(.dfu), .vdm(.dfuSilicon), .vdm(.dfuT2): "Entering DFU…"
        case .vdm(.restart): "Restarting…"
        case .vdm(.serial): "Starting serial console…"
        case .vdm(.debugUSB): "Switching to debug USB…"
        case .vdm(.probe): "Testing the port…"
        case .revive: "Reviving…"
        case .restore: "Restoring…"
        case .diskCheck: "Checking disk…"
        }
    }
}
