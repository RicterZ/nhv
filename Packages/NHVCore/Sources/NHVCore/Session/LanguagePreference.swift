import Foundation
import Observation

public enum AppLanguage: String, CaseIterable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    public struct Definition: Sendable {
        public let nativeName: String
        public let languageCode: String
        public let galleryTag: String
    }

    /// The picker, system default, and gallery filtering all use this definition.
    public var definition: Definition {
        switch self {
        case .simplifiedChinese: .init(nativeName: "简体中文", languageCode: "zh", galleryTag: "chinese")
        case .english: .init(nativeName: "English", languageCode: "en", galleryTag: "english")
        case .japanese: .init(nativeName: "日本語", languageCode: "ja", galleryTag: "japanese")
        }
    }

    public static func initial(preferredLanguages: [String]) -> AppLanguage {
        guard let primary = preferredLanguages.first else { return .english }
        let code = Locale(identifier: primary).language.languageCode?.identifier
        return allCases.first { $0.definition.languageCode == code } ?? .english
    }
}

@MainActor @Observable
public final class LanguagePreference {
    public var selection: AppLanguage {
        didSet { defaults.set(selection.rawValue, forKey: Self.storageKey) }
    }

    public var locale: Locale { Locale(identifier: selection.rawValue) }
    public var filterGalleries: Bool {
        didSet { defaults.set(filterGalleries, forKey: Self.filterKey) }
    }
    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "app.language"
    private static let filterKey = "app.filterGalleriesByLanguage"

    public init(defaults: UserDefaults = .standard, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.storageKey).flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.initial(preferredLanguages: preferredLanguages)
        filterGalleries = defaults.bool(forKey: Self.filterKey)
    }

    public func applyingFilter(to query: GalleryQuery) -> GalleryQuery {
        query.filtered(language: filterGalleries ? selection : nil)
    }
}
