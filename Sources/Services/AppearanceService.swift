import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case green = "Green"
    case teal = "Teal"
    case indigo = "Indigo"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        case .indigo: .indigo
        }
    }
}

enum AppFontSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .small: 0.9
        case .medium: 1.0
        case .large: 1.15
        }
    }
}

enum SidebarSize: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case standard = "Standard"
    case wide = "Wide"

    var id: String { rawValue }

    var width: CGFloat {
        switch self {
        case .compact: 160
        case .standard: 200
        case .wide: 250
        }
    }
}

@MainActor
@Observable
final class AppearanceService {
    static let shared = AppearanceService()

    var theme: AppTheme {
        didSet { save("theme", theme.rawValue) }
    }

    var accentColor: AccentColorOption {
        didSet { save("accentColor", accentColor.rawValue) }
    }

    var fontSize: AppFontSize {
        didSet { save("fontSize", fontSize.rawValue) }
    }

    var sidebarSize: SidebarSize {
        didSet { save("sidebarSize", sidebarSize.rawValue) }
    }

    var showEntryIcons: Bool {
        didSet { save("showEntryIcons", showEntryIcons) }
    }

    var compactList: Bool {
        didSet { save("compactList", compactList) }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.theme = AppTheme(rawValue: defaults.string(forKey: "pv.theme") ?? "") ?? .system
        self.accentColor = AccentColorOption(rawValue: defaults.string(forKey: "pv.accentColor") ?? "") ?? .blue
        self.fontSize = AppFontSize(rawValue: defaults.string(forKey: "pv.fontSize") ?? "") ?? .medium
        self.sidebarSize = SidebarSize(rawValue: defaults.string(forKey: "pv.sidebarSize") ?? "") ?? .standard
        self.showEntryIcons = defaults.object(forKey: "pv.showEntryIcons") as? Bool ?? true
        self.compactList = defaults.object(forKey: "pv.compactList") as? Bool ?? false
    }

    private func save(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: "pv.\(key)")
    }
}
