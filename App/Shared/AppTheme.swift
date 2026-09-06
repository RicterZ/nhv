import SwiftUI

enum AppTheme: String {
    case dark
    case light

    static let storageKey = "app.theme"

    var accentColor: Color {
        switch self {
        case .dark: Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)
        case .light: Color(uiColor: .systemBlue)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }
}
