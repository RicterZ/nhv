import Foundation

public enum SearchTerms {
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
