import SwiftUI

struct SearchTermChips: View {
    let terms: [String]
    let remove: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
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
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Remove filter: \(term)"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
