import SwiftUI
import UIKit

struct TagAutocompleteSuggestions: View {
    let suggestions: [TagTranslationStore.Suggestion]
    let showsTranslations: Bool
    @Environment(\.usesNavigationRailLayout) private var usesNavigationRailLayout
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let select: (TagTranslationStore.Suggestion) -> Void

    private var rowHeight: CGFloat { showsTranslations ? 60 : 50 }
    private var containerHeight: CGFloat {
        min(CGFloat(suggestions.count), 4.5) * rowHeight
    }

    private var compactWidth: CGFloat {
        // Measure both lines so short suggestions wrap naturally, while long
        // queries stay within a readable panel and truncate as before.
        _ = dynamicTypeSize
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let primaryFont = UIFont.systemFont(ofSize: bodyFont.pointSize, weight: .medium)
        let secondaryFont = UIFont.preferredFont(forTextStyle: .subheadline)
        let textWidth = suggestions.map { suggestion in
            let primary = showsTranslations ? suggestion.translatedName : suggestion.searchQuery
            let primaryWidth = (primary as NSString).size(withAttributes: [.font: primaryFont]).width
            let secondaryWidth = showsTranslations
                ? (suggestion.searchQuery as NSString).size(withAttributes: [.font: secondaryFont]).width : 0
            return max(primaryWidth, secondaryWidth)
        }.max() ?? 0
        return min(440, max(180, ceil(textWidth) + 76))
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
        .frame(maxWidth: usesNavigationRailLayout ? compactWidth : .infinity)
        .modifier(TagAutocompleteGlass())
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 1)
        .frame(maxWidth: .infinity, alignment: .trailing)
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
