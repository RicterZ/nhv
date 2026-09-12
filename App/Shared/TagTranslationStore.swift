import Foundation
import NHVCore
import Observation

@MainActor @Observable
final class TagTranslationStore {
    struct Suggestion: Identifiable, Equatable {
        let namespace: String
        let sourceName: String
        let translatedName: String
        let displayQuery: String
        let searchQuery: String
        let matchedText: String

        var id: String { namespace + "\u{0}" + sourceName }
    }

    private struct Database: Decodable, Sendable {
        let translations: [String: [String: String]]
    }

    private struct Candidate: Sendable {
        let namespace: String
        let sourceName: String
        let translatedName: String
        let normalizedSourceName: String
        let normalizedTranslatedName: String

        init(namespace: String, sourceName: String, translatedName: String) {
            self.namespace = namespace
            self.sourceName = sourceName
            self.translatedName = translatedName
            normalizedSourceName = TagTranslationStore.normalized(sourceName)
            normalizedTranslatedName = TagTranslationStore.normalized(translatedName)
        }
    }

    private struct Index: Sendable {
        let namespaces: [String: [String: String]]
        let genericTags: [String: String]
        let candidatesByNamespace: [String: [Candidate]]
        let allCandidates: [Candidate]
    }

    private(set) var isReady = false
    @ObservationIgnored private var index = Index(
        namespaces: [:], genericTags: [:], candidatesByNamespace: [:], allCandidates: [])
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

    func suggestions(for input: String, includesTranslations: Bool, limit: Int = 12) -> [Suggestion] {
        guard isReady, limit > 0, let request = Self.parse(input) else { return [] }
        let candidates = request.namespace.flatMap { index.candidatesByNamespace[$0] } ?? index.allCandidates
        let needle = Self.normalized(request.value)
        guard !needle.isEmpty else { return [] }

        var matches: [(rank: Int, candidate: Candidate)] = []
        matches.reserveCapacity(limit)

        for candidate in candidates {
            var rank = Self.matchRank(candidate: candidate.normalizedSourceName, needle: needle)
            if includesTranslations,
               let translatedRank = Self.matchRank(candidate: candidate.normalizedTranslatedName, needle: needle) {
                rank = min(rank ?? translatedRank, translatedRank)
            }
            guard let rank else { continue }
            let match = (rank, candidate)
            if let insertionIndex = matches.firstIndex(where: { Self.isOrdered(match, before: $0) }) {
                matches.insert(match, at: insertionIndex)
                if matches.count > limit { matches.removeLast() }
            } else if matches.count < limit {
                matches.append(match)
            }
        }

        return matches.map { _, candidate in
            let field = request.field ?? Self.searchField(for: candidate.namespace)
            let searchQuery = request.exclusion + field + ":" + Self.quotedIfNeeded(candidate.sourceName)
            return Suggestion(
                namespace: candidate.namespace,
                sourceName: candidate.sourceName,
                translatedName: candidate.translatedName,
                displayQuery: searchQuery,
                searchQuery: searchQuery,
                matchedText: request.value
            )
        }
    }

    func resolvedQuery(for input: String, includesTranslations: Bool) -> String {
        guard includesTranslations,
              let suggestion = suggestions(for: input, includesTranslations: true, limit: 1).first,
              Self.parse(input).map({ Self.normalized($0.value) }) == Self.normalized(suggestion.translatedName)
        else { return input }
        return suggestion.searchQuery
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

        var candidatesByNamespace: [String: [Candidate]] = [:]
        for (namespace, translations) in database.translations where namespace != "rows" {
            candidatesByNamespace[namespace] = translations.map {
                Candidate(namespace: namespace, sourceName: $0.key, translatedName: $0.value)
            }
        }

        // Prefer namespaces that nhentai can express directly when an English
        // label exists in more than one database catalog.
        let namespaceOrder = [
            "language", "parody", "character", "group", "artist", "reclass",
            "female", "male", "mixed", "other", "location", "cosplayer"
        ]
        var seen = Set<String>()
        var allCandidates: [Candidate] = []
        for namespace in namespaceOrder {
            for candidate in candidatesByNamespace[namespace] ?? [] where seen.insert(candidate.sourceName).inserted {
                allCandidates.append(candidate)
            }
        }
        return Index(namespaces: database.translations, genericTags: genericTags,
            candidatesByNamespace: candidatesByNamespace, allCandidates: allCandidates)
    }

    private struct Request {
        let exclusion: String
        let field: String?
        let namespace: String?
        let value: String
    }

    nonisolated private static func parse(_ input: String) -> Request? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let exclusion = text.hasPrefix("-") ? "-" : ""
        if !exclusion.isEmpty { text.removeFirst() }

        let namespaceByField = [
            "artist": "artist", "author": "artist", "group": "group", "parody": "parody",
            "character": "character", "language": "language", "category": "reclass"
        ]
        var field: String?
        var namespace: String?
        var value = text
        if let colon = text.firstIndex(of: ":") {
            let candidate = String(text[..<colon]).lowercased()
            if candidate == "tag" || namespaceByField[candidate] != nil {
                field = candidate == "author" ? "artist" : candidate
                namespace = namespaceByField[candidate]
                value = String(text[text.index(after: colon)...])
            }
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\""))
        guard !value.isEmpty else { return nil }
        return Request(exclusion: exclusion, field: field, namespace: namespace, value: value)
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }

    nonisolated private static func matchRank(candidate: String, needle: String) -> Int? {
        if candidate == needle { return 0 }
        if candidate.hasPrefix(needle) { return 1 }
        if candidate.contains(needle) { return 2 }
        return nil
    }

    nonisolated private static func searchField(for namespace: String) -> String {
        switch namespace {
        case "language", "parody", "character", "group", "artist": namespace
        case "reclass": "category"
        default: "tag"
        }
    }

    nonisolated private static func isOrdered(
        _ lhs: (rank: Int, candidate: Candidate),
        before rhs: (rank: Int, candidate: Candidate)
    ) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        if lhs.candidate.sourceName.count != rhs.candidate.sourceName.count {
            return lhs.candidate.sourceName.count < rhs.candidate.sourceName.count
        }
        return lhs.candidate.sourceName.localizedStandardCompare(rhs.candidate.sourceName) == .orderedAscending
    }

    nonisolated private static func quotedIfNeeded(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return value.contains(where: \.isWhitespace) ? "\"\(escaped)\"" : escaped
    }
}
