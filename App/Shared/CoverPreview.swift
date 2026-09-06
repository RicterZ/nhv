import SwiftUI
import Observation
import UIKit

enum ContentDisplayPreference {
    static let nsfwKey = "content.nsfwEnabled"
}

@MainActor @Observable
final class CoverPreview {
    struct Item {
        let id: Int
        let url: URL?
        let title: String
    }

    var item: Item?

    func show(_ item: Item) {
        guard self.item?.id != item.id else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.65)
        self.item = item
    }

    func dismiss(id: Int) {
        if item?.id == id { item = nil }
    }
}

struct CoverPreviewOverlay: View {
    let item: CoverPreview.Item
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                GalleryCover(url: item.url, retainsLoadedImage: true, letterboxColor: .clear)
                    .frame(height: max(100, geometry.size.height * 0.62))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(verbatim: item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(16)
            .frame(width: min(440, max(0, geometry.size.width - 40)))
            .modifier(CoverPreviewGlass())
            .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Keep the originating finger on the cover's recognizer until release.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}

private struct CoverPreviewGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        }
    }
}

/// A held preview must end on release/cancellation, unlike a context menu.
struct CoverHoldGesture: UIViewRepresentable {
    let open: () -> Void
    let preview: (Bool) -> Void

    func makeUIView(context: Context) -> CoverHoldView { CoverHoldView() }

    func updateUIView(_ view: CoverHoldView, context: Context) {
        view.open = open
        view.preview = preview
    }

    static func dismantleUIView(_ view: CoverHoldView, coordinator: ()) {
        view.preview?(false)
    }
}

final class CoverHoldView: UIView {
    var open: (() -> Void)?
    var preview: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = false
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.35
        hold.allowableMovement = 12
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.require(toFail: hold)
        addGestureRecognizer(hold)
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { open?() }

    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began: preview?(true)
        case .changed:
            if !bounds.contains(gesture.location(in: self)) { preview?(false) }
        case .ended, .cancelled, .failed: preview?(false)
        default: break
        }
    }
}
