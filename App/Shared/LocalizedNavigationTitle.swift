import SwiftUI

enum AppLocalization {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let bundle = Bundle.main.path(forResource: identifier, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return String(localized: key, bundle: bundle, locale: locale)
    }
}

private struct LocalizedNavigationTitle: ViewModifier {
    let title: String.LocalizationValue
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        // Give UIKit a changed title value when the in-app locale changes.
        content.navigationTitle(Text(verbatim: AppLocalization.string(title, locale: locale)))
    }
}

extension View {
    func localizedNavigationTitle(_ title: String.LocalizationValue) -> some View {
        modifier(LocalizedNavigationTitle(title: title))
    }
}
