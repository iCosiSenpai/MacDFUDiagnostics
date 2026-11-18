import SwiftUI
import AppKit
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Equatable, Sendable {
    case it = "it"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .it: "🇮🇹 Italiano"
        case .en: "🇬🇧 English"
        }
    }

    func text(_ it: String, _ en: String) -> String {
        self == .it ? it : en
    }

    static var systemResolved: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "it"
        return preferred.hasPrefix("it") ? .it : .en
    }
}

enum AppLanguagePreference: String, CaseIterable, Identifiable, Equatable, Sendable {
    case system = "system"
    case it = "it"
    case en = "en"

    var id: String { rawValue }

    var resolved: AppLanguage {
        switch self {
        case .system: AppLanguage.systemResolved
        case .it: .it
        case .en: .en
        }
    }

    func label(in lang: AppLanguage) -> String {
        switch self {
        case .system:
            let sysName = AppLanguage.systemResolved == .it ? "Italiano" : "English"
            return lang.text("Automatica (Sistema — \(sysName))", "Automatic (System — \(sysName))")
        case .it:
            return "🇮🇹 Italiano"
        case .en:
            return "🇬🇧 English"
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    func label(in lang: AppLanguage) -> String {
        switch self {
        case .system: lang.text("Automatico (Sistema)", "Automatic (System)")
        case .light: lang.text("Chiaro (Light)", "Light")
        case .dark: lang.text("Scuro (Dark)", "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    @MainActor
    func applyToNSApp() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
@Observable
final class AppPreferences {
    var languagePreference: AppLanguagePreference {
        didSet {
            UserDefaults.standard.set(languagePreference.rawValue, forKey: "MacDFU.languagePref")
        }
    }

    var language: AppLanguage {
        languagePreference.resolved
    }

    var theme: AppThemeMode {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "MacDFU.theme")
            theme.applyToNSApp()
        }
    }

    var pollingIntervalSeconds: Double {
        didSet {
            UserDefaults.standard.set(pollingIntervalSeconds, forKey: "MacDFU.pollingInterval")
        }
    }

    var playSoundOnDFUDetection: Bool {
        didSet {
            UserDefaults.standard.set(playSoundOnDFUDetection, forKey: "MacDFU.playSoundOnDFU")
        }
    }

    var autoSelectHostDFUPort: Bool {
        didSet {
            UserDefaults.standard.set(autoSelectHostDFUPort, forKey: "MacDFU.autoSelectHostDFUPort")
        }
    }

    var preventHostSleepAlways: Bool {
        didSet {
            UserDefaults.standard.set(preventHostSleepAlways, forKey: "MacDFU.preventHostSleep")
            updateSleepAssertion()
        }
    }

    var requireDoubleConfirmForRestore: Bool {
        didSet {
            UserDefaults.standard.set(requireDoubleConfirmForRestore, forKey: "MacDFU.doubleConfirmRestore")
        }
    }

    var serialBaudRate: Int {
        didSet {
            UserDefaults.standard.set(serialBaudRate, forKey: "MacDFU.serialBaudRate")
        }
    }

    var defaultIPSWDirectoryPath: String {
        didSet {
            UserDefaults.standard.set(defaultIPSWDirectoryPath, forKey: "MacDFU.defaultIPSWDir")
        }
    }

    private var sleepActivity: NSObjectProtocol?

    init() {
        if let savedLang = UserDefaults.standard.string(forKey: "MacDFU.languagePref"),
           let parsed = AppLanguagePreference(rawValue: savedLang) {
            self.languagePreference = parsed
        } else if let legacyLang = UserDefaults.standard.string(forKey: "MacDFU.language"),
                  let parsedLegacy = AppLanguagePreference(rawValue: legacyLang) {
            self.languagePreference = parsedLegacy
        } else {
            self.languagePreference = .system
        }

        if let savedTheme = UserDefaults.standard.string(forKey: "MacDFU.theme"),
           let parsedTheme = AppThemeMode(rawValue: savedTheme) {
            self.theme = parsedTheme
        } else {
            self.theme = .system
        }

        let savedPolling = UserDefaults.standard.double(forKey: "MacDFU.pollingInterval")
        self.pollingIntervalSeconds = savedPolling > 0 ? savedPolling : 2.5

        if UserDefaults.standard.object(forKey: "MacDFU.playSoundOnDFU") != nil {
            self.playSoundOnDFUDetection = UserDefaults.standard.bool(forKey: "MacDFU.playSoundOnDFU")
        } else {
            self.playSoundOnDFUDetection = true
        }

        if UserDefaults.standard.object(forKey: "MacDFU.autoSelectHostDFUPort") != nil {
            self.autoSelectHostDFUPort = UserDefaults.standard.bool(forKey: "MacDFU.autoSelectHostDFUPort")
        } else {
            self.autoSelectHostDFUPort = true
        }

        self.preventHostSleepAlways = UserDefaults.standard.bool(forKey: "MacDFU.preventHostSleep")

        if UserDefaults.standard.object(forKey: "MacDFU.doubleConfirmRestore") != nil {
            self.requireDoubleConfirmForRestore = UserDefaults.standard.bool(forKey: "MacDFU.doubleConfirmRestore")
        } else {
            self.requireDoubleConfirmForRestore = true
        }

        let savedBaud = UserDefaults.standard.integer(forKey: "MacDFU.serialBaudRate")
        self.serialBaudRate = savedBaud > 0 ? savedBaud : 115200

        let defaultDownloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        self.defaultIPSWDirectoryPath = UserDefaults.standard.string(forKey: "MacDFU.defaultIPSWDir") ?? defaultDownloads

        updateSleepAssertion()
    }

    private func updateSleepAssertion() {
        if preventHostSleepAlways {
            if sleepActivity == nil {
                sleepActivity = ProcessInfo.processInfo.beginActivity(
                    options: [.userInitiated, .idleSystemSleepDisabled],
                    reason: "Mac DFU Studio active monitoring"
                )
            }
        } else if let activity = sleepActivity {
            ProcessInfo.processInfo.endActivity(activity)
            sleepActivity = nil
        }
    }

    func resetToDefaults() {
        languagePreference = .system
        theme = .system
        pollingIntervalSeconds = 2.5
        playSoundOnDFUDetection = true
        autoSelectHostDFUPort = true
        preventHostSleepAlways = false
        requireDoubleConfirmForRestore = true
        serialBaudRate = 115200
        defaultIPSWDirectoryPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    }

    func tr(_ it: String, _ en: String) -> String {
        language.text(it, en)
    }
}

// MARK: - Design System & Adaptive Theme Styling
enum AppPalette {
    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(nsColor: .controlBackgroundColor).opacity(0.65)
            : Color.white.opacity(0.92)
    }

    static func elevatedBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.035)
    }

    static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.11)
            : Color.black.opacity(0.09)
    }

    static func heroGradient(for scheme: ColorScheme, hasTarget: Bool) -> LinearGradient {
        if hasTarget {
            return LinearGradient(
                colors: scheme == .dark
                    ? [Color(red: 0.04, green: 0.24, blue: 0.22), Color(red: 0.06, green: 0.14, blue: 0.28)]
                    : [Color(red: 0.86, green: 0.98, blue: 0.94), Color(red: 0.88, green: 0.94, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: scheme == .dark
                    ? [Color(red: 0.09, green: 0.12, blue: 0.22), Color(red: 0.06, green: 0.08, blue: 0.15)]
                    : [Color(red: 0.91, green: 0.95, blue: 1.0), Color(red: 0.96, green: 0.97, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct StyledCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppPalette.cardBackground(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.06),
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppPalette.cardBorder(for: colorScheme), lineWidth: 1)
            )
    }
}

extension View {
    func styledCard(padding: CGFloat = 16) -> some View {
        modifier(StyledCardModifier(padding: padding))
    }
}
