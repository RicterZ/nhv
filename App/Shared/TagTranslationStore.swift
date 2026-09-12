import Foundation
import NHVCore
import Observation

@MainActor @Observable
final class TagTranslationStore {
    private struct Database: Decodable, Sendable {
        let translations: [String: [String: String]]
    }

    private struct Index: Sendable {
        let namespaces: [String: [String: String]]
        let genericTags: [String: String]
    }

    private(set) var isReady = false
    @ObservationIgnored private var index = Index(namespaces: [:], genericTags: [:])
    @ObservationIgnored private var loadTask: Task<Index, any Error>?

    func prepare() async {
        guard !isReady else { return }
        if loadTask == nil {
            loadTask = Task.detached(priority: .utility) { try Self.loadIndex() }
        }
        guard let loadTask else { return }
        do {
            index = try await loadTask.value
            isReady = true
        } catch {
            // Translation is optional; untranslated labels remain usable if
            // the bundled resource cannot be read.
        }
        self.loadTask = nil
    }

    func displayName(for tag: Tag) -> String {
        guard isReady else { return tag.name }
        let key = tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return tag.name }

        let namespace: String?
        switch tag.type {
        case "author": namespace = "artist"
        case "category": namespace = "reclass"
        case "tag": namespace = nil
        default: namespace = tag.type
        }

        let translated: String?
        if let namespace {
            translated = index.namespaces[namespace]?[key]
        } else {
            translated = index.genericTags[key]
        }
        guard let translated, !translated.isEmpty else { return tag.name }
        return translated
    }

    nonisolated private static func loadIndex() throws -> Index {
        let url = Bundle.main.url(forResource: "tag-translations", withExtension: "json", subdirectory: "TagTranslations")
            ?? Bundle.main.url(forResource: "tag-translations", withExtension: "json")
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        let database = try JSONDecoder().decode(Database.self, from: Data(contentsOf: url))

        // nhentai exposes one combined `tag` namespace. Prefer the common
        // female namespace when the upstream database has gendered duplicates.
        let genericNamespaces = ["female", "male", "mixed", "other", "location", "cosplayer"]
        var genericTags: [String: String] = [:]
        for namespace in genericNamespaces.reversed() {
            guard let translations = database.translations[namespace] else { continue }
            genericTags.merge(translations) { _, preferred in preferred }
        }
        return Index(namespaces: database.translations, genericTags: genericTags)
    }
}
