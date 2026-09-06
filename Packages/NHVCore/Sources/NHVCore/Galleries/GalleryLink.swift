import Foundation

public enum GalleryLink {
    /// Accept a gallery URL, optionally followed by a numeric reader page.
    /// Anchor the entire value so lookalike hosts and malformed paths fail.
    public static func id(in text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\A(?i:https?://nhentai\.net)/g/([0-9]+)(?:/[0-9]+)?/?\z"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value),
              let id = Int(value[range]), id > 0 else { return nil }
        return id
    }
}
