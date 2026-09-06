import SwiftUI

enum AppTheme: String {
    case dark
    case light

    static let storageKey = "app.theme"

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }
}
