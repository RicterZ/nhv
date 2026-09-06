import SwiftUI
import NHVCore

struct SearchTermChips: View {
    let terms: [String]
    @Binding var sort: GallerySort
    let remove: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            GallerySortPicker(selection: $sort, usesChipStyle: true)
            ForEach(terms, id: \.self) { term in
                Button {
                    remove(term)
                } label: {
                    HStack(spacing: 8) {
                        Text(verbatim: term)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                    }
                    .modifier(GalleryFilterChipStyle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Remove filter: \(term)"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
