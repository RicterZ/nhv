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
        SearchTokenScanner(query).ranges.map { String(query[$0]) }
    }
}
