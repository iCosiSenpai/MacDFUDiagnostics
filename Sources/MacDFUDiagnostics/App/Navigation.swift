import Observation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case connect
    case disks
    case macs

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .connect: "Connect"
        case .disks: "Disks"
        case .macs: "Macs"
        }
    }

    var symbol: String {
        switch self {
        case .connect: "cable.connector"
        case .disks: "externaldrive"
        case .macs: "macbook.and.iphone"
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case device
    case activity
    case history

    var id: String { rawValue }
}

/// Where the user is in the window. Shared with the menu bar so commands can move around too.
@MainActor
@Observable
final class Navigation {
    var section: AppSection = LaunchOptions.section ?? .connect
    var showsInspector = LaunchOptions.inspector != nil
    var inspectorTab: InspectorTab = LaunchOptions.inspector ?? .device
    var showsRestoreSheet = LaunchOptions.sheet == "restore"
    var showsPortGuide = false
    var showsManualDFU = LaunchOptions.sheet == "manual"
    var showsWelcome = LaunchOptions.sheet == "welcome"
    var settingsTab: SettingsTab = .general

    func showActivity() {
        inspectorTab = .activity
        showsInspector = true
    }
}
