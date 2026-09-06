import SwiftUI
import NHVCore

struct SearchHistoryView: View {
    let history: SearchHistory
    let select: (String) -> Void

    var body: some View {
        if !history.queries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Search History")
                        .font(.headline)
                    Spacer()
                    Button("Clear History") { history.clear() }
                        .font(.subheadline)
                }

                FlowLayout(spacing: 6) {
                    ForEach(history.queries, id: \.self) { query in
                        Button {
                            select(query)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                Text(verbatim: query)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .modifier(GalleryFilterChipStyle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
