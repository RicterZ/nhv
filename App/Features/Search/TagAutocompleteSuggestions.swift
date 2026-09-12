import SwiftUI

struct TagAutocompleteSuggestions: View {
    let suggestions: [TagTranslationStore.Suggestion]
    let showsTranslations: Bool
    let select: (TagTranslationStore.Suggestion) -> Void

    private var rowHeight: CGFloat { showsTranslations ? 60 : 50 }
    private var containerHeight: CGFloat {
        min(CGFloat(suggestions.count), 4.5) * rowHeight
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        select(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tag")
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                if showsTranslations {
                                    HighlightedSuggestionText(
                                        text: suggestion.translatedName,
                                        matchedText: suggestion.matchedText,
                                        baseUIColor: .label)
                                        .font(.body.weight(.medium))
                                    HighlightedSuggestionText(
                                        text: suggestion.searchQuery,
                                        matchedText: suggestion.matchedText,
                                        baseUIColor: .secondaryLabel)
                                        .font(.subheadline)
                                } else {
                                    HighlightedSuggestionText(
                                        text: suggestion.searchQuery,
                                        matchedText: suggestion.matchedText,
                                        baseUIColor: .label)
                                        .font(.body.weight(.medium))
                                }
                            }
                            Spacer(minLength: 8)
                        }
                        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: containerHeight)
        .modifier(TagAutocompleteGlass())
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 1)
    }
}

private struct TagAutocompleteGlass: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape
                        .stroke(.primary.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        }
    }
}

private struct HighlightedSuggestionText: View {
    let text: String
    let matchedText: String
    let baseUIColor: UIColor

    var body: some View {
        Text(highlightedText)
            .lineLimit(1)
    }

    private var highlightedText: AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = Color(uiColor: baseUIColor)
        guard !matchedText.isEmpty,
              let match = text.range(
                of: matchedText,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]),
              let attributedMatch = Range(match, in: result)
        else { return result }
        result[attributedMatch].foregroundColor = .accentColor
        return result
    }
}
