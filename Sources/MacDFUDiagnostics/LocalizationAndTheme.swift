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

    var shortBadge: String {
        switch self {
        case .it: "IT"
        case .en: "EN"
        }
    }

    func text(_ it: String, _ en: String) -> String {
        self == .it ? it : en
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
        case .system: lang.text("Sistema", "System")
        case .light: lang.text("Chiaro", "Light")
        case .dark: lang.text("Scuro", "Dark")
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
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "MacDFU.language")
        }
    }

    var theme: AppThemeMode {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "MacDFU.theme")
            theme.applyToNSApp()
        }
    }

    init() {
        if let savedLang = UserDefaults.standard.string(forKey: "MacDFU.language"),
           let parsed = AppLanguage(rawValue: savedLang) {
            self.language = parsed
        } else {
            self.language = .it
        }

        if let savedTheme = UserDefaults.standard.string(forKey: "MacDFU.theme"),
           let parsedTheme = AppThemeMode(rawValue: savedTheme) {
            self.theme = parsedTheme
        } else {
            self.theme = .system
        }
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
