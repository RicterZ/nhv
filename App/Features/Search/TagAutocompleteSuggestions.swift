import SwiftUI
import UIKit

struct TagAutocompleteSuggestions: View {
    let suggestions: [TagTranslationStore.Suggestion]
    let showsTranslations: Bool
    @Environment(\.usesNavigationRailLayout) private var usesNavigationRailLayout
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
                            .frame(maxWidth: usesNavigationRailLayout ? .infinity : nil, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: usesNavigationRailLayout)
                            Spacer(minLength: usesNavigationRailLayout ? 0 : 8)
                        }
                        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: usesNavigationRailLayout ? nil : rowHeight, alignment: .leading)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(usesNavigationRailLayout ? .horizontal : [], 0, for: .scrollContent)
        .scrollIndicators(.hidden)
        .frame(height: containerHeight)
        .frame(maxWidth: .infinity)
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
    @Environment(\.usesNavigationRailLayout) private var usesNavigationRailLayout

    var body: some View {
        Text(highlightedText)
            .lineLimit(usesNavigationRailLayout ? nil : 1)
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
