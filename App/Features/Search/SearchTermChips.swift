import SwiftUI
import NHVCore

struct SearchTermChips: View {
    let terms: [String]
    let remove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(terms, id: \.self) { term in
                    Button {
                        remove(term)
                    } label: {
                        HStack(spacing: 8) {
                            Text(verbatim: term)
                                .lineLimit(1)
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.semibold))
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .modifier(GalleryFilterChipStyle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove filter: \(term)"))
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
