import Foundation

public struct SearchSyntax: Identifiable, Sendable, Equatable {
    public let id: String
    public let insertion: String
    public let example: String

    public static let all: [SearchSyntax] = [
        .init(id: "id", insertion: "id:", example: "id:123456"),
        .init(id: "tag", insertion: "tag:\"\"", example: "tag:\"name\""),
        .init(id: "artist", insertion: "artist:\"\"", example: "artist:\"name\""),
        .init(id: "parody", insertion: "parody:\"\"", example: "parody:\"name\""),
        .init(id: "character", insertion: "character:\"\"", example: "character:\"name\""),
        .init(id: "group", insertion: "group:\"\"", example: "group:\"name\""),
        .init(id: "language", insertion: "language:\"\"", example: "language:\"english\""),
        .init(id: "category", insertion: "category:\"\"", example: "category:\"doujinshi\""),
        .init(id: "pages", insertion: "pages:", example: "pages:>20"),
        .init(id: "favorites", insertion: "favorites:", example: "favorites:>=100"),
        .init(id: "uploaded", insertion: "uploaded:", example: "uploaded:<7d"),
        .init(id: "title", insertion: "title:\"\"", example: "title:\"…\""),
        .init(id: "jtitle", insertion: "jtitle:\"\"", example: "jtitle:\"…\""),
        .init(id: "phrase", insertion: "\"\"", example: "\"…\"")
    ]

    public static func suggestions(for input: String) -> [SearchSyntax] {
        let fragment = input[tokenStart(in: input)...]
        let prefix = fragment.hasPrefix("-") ? fragment.dropFirst() : fragment[...]
        guard !prefix.contains(":"), !prefix.contains("\"") else { return [] }
        return all.filter {
            ($0.id != "id" || !fragment.hasPrefix("-")) &&
            (prefix.isEmpty || $0.insertion.hasPrefix(prefix.lowercased()))
        }
    }

    public func applying(to input: String) -> String {
        let start = Self.tokenStart(in: input)
        let exclude = input[start...].hasPrefix("-") ? "-" : ""
        return String(input[..<start]) + exclude + insertion
    }

    public struct Completion: Equatable, Sendable {
        public let text: String
        public let caretUTF16Offset: Int
    }

    public func completion(in input: String) -> Completion {
        let text = applying(to: input)
        return Completion(text: text, caretUTF16Offset: text.utf16.count - (insertion.hasSuffix("\"\"") ? 1 : 0))
    }

    public static func isExcluding(in input: String) -> Bool {
        input[tokenStart(in: input)...].hasPrefix("-")
    }

    private static func tokenStart(in input: String) -> String.Index {
        var start = input.startIndex
        var quoted = false
        var escaped = false
        for index in input.indices {
            let character = input[index]
            if escaped { escaped = false; continue }
            if character == "\\" { escaped = true }
            else if character == "\"" { quoted.toggle() }
            else if character.isWhitespace && !quoted { start = input.index(after: index) }
        }
        return start
    }
}
