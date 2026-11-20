import AppKit
import Observation
import SwiftUI

enum AppearanceChoice: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum LanguageChoice: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case italian = "it"

    var id: String { rawValue }

    /// The locale to force on the interface, or `nil` to follow the system — which already accounts
    /// for a per-app language chosen in System Settings.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .italian: Locale(identifier: "it")
        }
    }
}

/// The user's settings, kept in `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let appearance = "appearance"
        static let language = "language"
        static let appleLanguages = "AppleLanguages"
        static let shaders = "effects.shaders"
        static let motion = "effects.motion"
        static let sounds = "sounds"
        static let keepAwake = "keepAwake"
        static let baudRate = "serial.baudRate"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var awakeActivity: NSObjectProtocol?

    var appearance: AppearanceChoice {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            NSApplication.shared.appearance = appearance.nsAppearance
        }
    }

    /// The interface language. SwiftUI text follows it at once; menus and system panels follow it from
    /// the next launch, which is when macOS reads the app's language list.
    var language: LanguageChoice {
        didSet {
            defaults.set(language.rawValue, forKey: Key.language)
            if language == .system {
                defaults.removeObject(forKey: Key.appleLanguages)
            } else {
                defaults.set([language.rawValue], forKey: Key.appleLanguages)
            }
        }
    }

    /// The animated, GPU-drawn background.
    var shaderEffects: Bool {
        didSet { defaults.set(shaderEffects, forKey: Key.shaders) }
    }

    /// Animations, transitions and the small reactions to pointer and state.
    var motionEffects: Bool {
        didSet { defaults.set(motionEffects, forKey: Key.motion) }
    }

    var sounds: Bool {
        didSet { defaults.set(sounds, forKey: Key.sounds) }
    }

    /// Keeps the Mac from sleeping for as long as the app is open. (It never sleeps mid-restore anyway.)
    var keepAwake: Bool {
        didSet {
            defaults.set(keepAwake, forKey: Key.keepAwake)
            applyKeepAwake()
        }
    }

    var baudRate: Int {
        didSet { defaults.set(baudRate, forKey: Key.baudRate) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.shaders: true,
            Key.motion: true,
            Key.sounds: true,
            Key.baudRate: 115_200,
        ])

        // Versions before 2.0 stored these two under other names; carry the choice over.
        let savedAppearance = defaults.string(forKey: Key.appearance) ?? defaults.string(forKey: "MacDFU.theme")
        let savedLanguage = defaults.string(forKey: Key.language) ?? defaults.string(forKey: "MacDFU.languagePref")
        appearance = AppearanceChoice(rawValue: savedAppearance ?? "") ?? .system
        language = LanguageChoice(rawValue: savedLanguage ?? "") ?? .system
        shaderEffects = defaults.bool(forKey: Key.shaders)
        motionEffects = defaults.bool(forKey: Key.motion)
        sounds = defaults.bool(forKey: Key.sounds)
        keepAwake = defaults.bool(forKey: Key.keepAwake)
        let savedBaud = defaults.integer(forKey: Key.baudRate)
        baudRate = DiagnosticsEngine.baudRates.contains(savedBaud) ? savedBaud : 115_200

        applyKeepAwake()
    }

    /// Whether every effect is switched off.
    var allEffectsOff: Bool {
        !shaderEffects && !motionEffects
    }

    /// One switch for everything that moves or glows.
    func setAllEffects(_ enabled: Bool) {
        shaderEffects = enabled
        motionEffects = enabled
    }

    func applyAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }

    func resetToDefaults() {
        appearance = .system
        language = .system
        shaderEffects = true
        motionEffects = true
        sounds = true
        keepAwake = false
        baudRate = 115_200
    }

    private func applyKeepAwake() {
        if keepAwake, awakeActivity == nil {
            awakeActivity = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled], reason: "Mac DFU Studio is open")
        } else if !keepAwake, let activity = awakeActivity {
            ProcessInfo.processInfo.endActivity(activity)
            awakeActivity = nil
        }
    }
}
