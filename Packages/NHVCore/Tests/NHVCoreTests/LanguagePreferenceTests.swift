import Foundation
import Testing
@testable import NHVCore

@Test(arguments: ["zh-Hans-CN", "zh-Hant-TW", "zh-HK", "zh"])
func chineseSystemDefaultsToSimplifiedChinese(identifier: String) {
    #expect(AppLanguage.initial(preferredLanguages: [identifier]) == .simplifiedChinese)
}

@Test(arguments: ["en-US", "fr-FR", "de-DE", "ko-KR"])
func otherPrimaryLanguagesDefaultToEnglish(identifier: String) {
    #expect(AppLanguage.initial(preferredLanguages: [identifier, "zh-Hans"]) == .english)
}

@Test @MainActor func languageChoicePersistsAndOverridesSystemOnNextLaunch() throws {
    let suite = "NHV.LanguageTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = LanguagePreference(defaults: defaults, preferredLanguages: ["zh-Hans"])
    #expect(settings.selection == .simplifiedChinese)
    settings.selection = .english
    #expect(settings.locale.identifier == "en")
    let relaunched = LanguagePreference(defaults: defaults, preferredLanguages: ["zh-Hans"])
    #expect(relaunched.selection == .english)
    relaunched.selection = .simplifiedChinese
    #expect(LanguagePreference(defaults: defaults, preferredLanguages: ["ja"]).selection == .simplifiedChinese)
}

@Test func missingSystemLanguageDefaultsToEnglish() {
    #expect(AppLanguage.initial(preferredLanguages: []) == .english)
}

@Test func japaneseSystemDefaultsToJapanese() {
    #expect(AppLanguage.initial(preferredLanguages: ["ja-JP", "en"]) == .japanese)
}

@Test @MainActor func galleryLanguageFilterIsOptInAndPersists() throws {
    let suite = "NHV.LanguageTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = LanguagePreference(defaults: defaults, preferredLanguages: ["ja"])
    #expect(!settings.filterGalleries)
    #expect(settings.applyingFilter(to: .latest) == .latest)
    settings.filterGalleries = true
    #expect(settings.applyingFilter(to: .latest) == .search("language:japanese", .date))
    settings.selection = .simplifiedChinese
    #expect(settings.applyingFilter(to: .search(#"artist:"some artist" pages:>10"#, .week)) == .search(#"language:chinese artist:"some artist" pages:>10"#, .week))
    let relaunched = LanguagePreference(defaults: defaults, preferredLanguages: ["en"])
    #expect(relaunched.filterGalleries)
    #expect(relaunched.selection == .simplifiedChinese)
    relaunched.filterGalleries = false
    #expect(relaunched.applyingFilter(to: .search("artist:name", .month)) == .search("artist:name", .month))
}

@Test(arguments: AppLanguage.allCases)
func languageDefinitionsDriveFiltering(language: AppLanguage) {
    let query = GalleryQuery.latest.filtered(language: language)
    #expect(query == .search("language:\(language.definition.galleryTag)", .date))
    #expect(GalleryQuery.favorites("abc").filtered(language: language) == .favorites("abc"))
    #expect(!language.definition.nativeName.isEmpty)
}
