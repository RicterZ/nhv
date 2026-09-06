import SwiftUI
import NHVCore

struct SearchSyntaxSuggestions: View {
    let input: String
    let select: (SearchSyntax) -> Void

    var body: some View {
        let exclude = SearchSyntax.isExcluding(in: input)
        LazyVStack(alignment: .leading, spacing: 0) {
            Text("Prefix a term with - to exclude it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)

            ForEach(SearchSyntax.suggestions(for: input)) { syntax in
                Button {
                    select(syntax)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: (exclude ? "-" : "") + syntax.example)
                            .font(.system(.subheadline, design: .monospaced).weight(.medium))
                            .foregroundStyle(.tint)
                        description(for: syntax.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().opacity(0.4)
            }
        }
        .padding(.horizontal, 16)
    }

    private func description(for id: String) -> Text {
        switch id {
        case "tag": Text("Filter by tag")
        case "artist": Text("Filter by artist")
        case "parody": Text("Filter by parody")
        case "character": Text("Filter by character")
        case "group": Text("Filter by group")
        case "language": Text("Filter by language")
        case "category": Text("Filter by category")
        case "pages": Text("Filter by page count")
        case "favorites": Text("Filter by favorites")
        case "uploaded": Text("Filter by upload date")
        case "title": Text("Search title text")
        case "jtitle": Text("Search Japanese title")
        default: Text("Search exact phrase")
        }
    }
}
