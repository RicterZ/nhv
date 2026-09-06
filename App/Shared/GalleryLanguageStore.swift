import Foundation
import Observation
import NHVCore

@MainActor @Observable
final class GalleryLanguageStore {
    private var tagsByID: [Int: Tag] = [:]
    @ObservationIgnored private var request: Task<[Tag], any Error>?
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var retryAfter: Date?

    func prepare(api: NHentaiAPI) async {
        guard !loaded, retryAfter.map({ $0 <= Date() }) ?? true else { return }
        if request == nil {
            request = Task {
                var tags: [Tag] = []
                var page = 1
                while true {
                    let response = try await api.tags(type: .language, sort: .name, page: page, perPage: 100)
                    tags.append(contentsOf: response.result)
                    guard page < response.numPages else { return tags }
                    page += 1
                }
            }
        }
        guard let request else { return }
        do {
            remember(try await request.value)
            loaded = true
            retryAfter = nil
        } catch {
            // Language decoration must not prevent galleries from loading.
            if case .rateLimited(let delay) = error as? APIError {
                let seconds = delay ?? 30
                retryAfter = Date().addingTimeInterval(seconds.isFinite ? max(1, seconds) : 30)
            } else {
                retryAfter = Date().addingTimeInterval(15)
            }
        }
        self.request = nil
    }

    func remember(_ tags: [Tag]) {
        for tag in tags where tag.type == "language" { tagsByID[tag.id] = tag }
    }

    func languages(for ids: [Int]) -> [GalleryLanguage] {
        var seen: Set<String> = []
        return ids.compactMap { id in
            guard let tag = tagsByID[id], let language = GalleryLanguage(slug: tag.slug),
                  seen.insert(language.code).inserted else { return nil }
            return language
        }
    }
}

struct GalleryLanguage {
    let flag: String
    let code: String

    init?(slug: String) {
        switch slug.lowercased() {
        case "japanese": (flag, code) = ("🇯🇵", "ja")
        case "english": (flag, code) = ("🇬🇧", "en")
        case "chinese": (flag, code) = ("🇨🇳", "zh")
        case "korean": (flag, code) = ("🇰🇷", "ko")
        case "french": (flag, code) = ("🇫🇷", "fr")
        case "german": (flag, code) = ("🇩🇪", "de")
        case "spanish": (flag, code) = ("🇪🇸", "es")
        case "italian": (flag, code) = ("🇮🇹", "it")
        case "portuguese": (flag, code) = ("🇵🇹", "pt")
        case "russian": (flag, code) = ("🇷🇺", "ru")
        case "thai": (flag, code) = ("🇹🇭", "th")
        case "vietnamese": (flag, code) = ("🇻🇳", "vi")
        case "indonesian": (flag, code) = ("🇮🇩", "id")
        case "polish": (flag, code) = ("🇵🇱", "pl")
        case "dutch": (flag, code) = ("🇳🇱", "nl")
        case "turkish": (flag, code) = ("🇹🇷", "tr")
        case "ukrainian": (flag, code) = ("🇺🇦", "uk")
        case "hungarian": (flag, code) = ("🇭🇺", "hu")
        case "czech": (flag, code) = ("🇨🇿", "cs")
        case "arabic": (flag, code) = ("🇸🇦", "ar")
        case "finnish": (flag, code) = ("🇫🇮", "fi")
        case "swedish": (flag, code) = ("🇸🇪", "sv")
        case "danish": (flag, code) = ("🇩🇰", "da")
        case "greek": (flag, code) = ("🇬🇷", "el")
        case "romanian": (flag, code) = ("🇷🇴", "ro")
        default: return nil // "translated" and "rewrite" are not languages.
        }
    }
}
