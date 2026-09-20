import SwiftUI
import NHVCore

struct SearchHistoryView: View {
    let history: SearchHistory
    let select: (String) -> Void
    @State private var isExpanded = false

    private var controlSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        28
        #else
        44
        #endif
    }

    var body: some View {
        if !history.queries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search History")
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Button {
                            isExpanded = false
                            history.clear()
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: controlSize, height: controlSize)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("Clear History"))
                        .accessibilityIdentifier("searchHistory.clear")
                        Button {
                            isExpanded.toggle()
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .frame(width: controlSize, height: controlSize)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(isExpanded ? Text("Collapse") : Text("Expand"))
                        .accessibilityIdentifier("searchHistory.expand")
                    }
                    .font(.subheadline)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }

                if isExpanded {
                    FlowLayout(spacing: 6) { chips }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) { chips }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var chips: some View {
        ForEach(history.queries, id: \.self) { query in
            Button {
                select(query)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                    Text(verbatim: query)
                        .lineLimit(1)
                }
                .modifier(GalleryFilterChipStyle())
            }
            .buttonStyle(.plain)
        }
    }
}
