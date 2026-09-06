import Foundation

public enum SearchTerms {
    public enum DirectIDError: Error { case invalid }

    /// A local navigation command, never a server-side search filter.
    public static func directGalleryID(in query: String) throws -> Int? {
        let terms = split(query)
        guard let command = terms.first(where: { $0.lowercased().hasPrefix("id:") }) else { return nil }
        let digits = command.dropFirst(3)
        guard terms.count == 1, !digits.isEmpty,
              digits.utf8.allSatisfy({ (48...57).contains($0) }),
              let id = Int(digits), id > 0 else { throw DirectIDError.invalid }
        return id
    }

    /// Split on whitespace outside double quotes while preserving server syntax.
    public static func split(_ query: String) -> [String] {
        var terms: [String] = []
        var term = ""
        var quoted = false
        var escaped = false

        for character in query {
            if character.isWhitespace && !quoted && !escaped {
                if !term.isEmpty { terms.append(term); term = "" }
                continue
            }
            term.append(character)
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                quoted.toggle()
            }
        }
        if !term.isEmpty { terms.append(term) }
        return terms
    }
}
