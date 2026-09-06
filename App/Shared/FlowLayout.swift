import SwiftUI

/// Fits each item to its content and wraps rows within the available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangement(width proposedWidth: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let naturalSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let naturalWidth = naturalSizes.reduce(0) { $0 + $1.width } + CGFloat(max(0, subviews.count - 1)) * spacing
        let width = max(0, proposedWidth.flatMap { $0.isFinite ? $0 : nil } ?? naturalWidth)
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(ProposedViewSize(width: min(width, naturalSizes[index].width), height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
