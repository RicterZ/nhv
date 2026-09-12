import SwiftUI
import UIKit

struct ZoomablePage: UIViewRepresentable {
    let image: UIImage?
    let resetID: Int
    @Binding var isZoomed: Bool
    var pageTurnMode = PageTurnMode.tap
    let turnPage: (Int) -> Void
    var dismissalChanged: ((CGFloat) -> Void)?
    var dismissalEnded: ((Bool) -> Void)?

    func makeUIView(context: Context) -> PageScrollView {
        let view = PageScrollView()
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: PageScrollView, context: Context) {
        view.dismissalChanged = dismissalChanged
        view.dismissalEnded = dismissalEnded
        view.turnPage = turnPage
        view.pageTurnMode = pageTurnMode
        view.zoomChanged = { zoomed in
            DispatchQueue.main.async {
                if isZoomed != zoomed { isZoomed = zoomed }
            }
        }
        view.setImage(image)
        if view.resetID != resetID {
            view.resetID = resetID
            view.setZoomScale(1, animated: true)
        }
    }
}

final class PageScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var dismissalChanged: ((CGFloat) -> Void)?
    var dismissalEnded: ((Bool) -> Void)?
    private(set) var dismissalPan: UIPanGestureRecognizer!
    private let pageImage = UIImageView()
    private var fittedBounds = CGSize.zero
    var resetID = 0
    var turnPage: ((Int) -> Void)?
    var zoomChanged: ((Bool) -> Void)?
    private var pageTap: UITapGestureRecognizer!
    private var zoomTap: UITapGestureRecognizer!
    var doubleTapZoomEnabled = false {
        didSet { updateTapGestures() }
    }
    var pageTurnMode = PageTurnMode.tap {
        didSet {
            guard oldValue != pageTurnMode else { return }
            updateTapGestures()
            updatePanning()
        }
    }
    var pullToDismissEnabled = true {
        didSet {
            guard oldValue != pullToDismissEnabled else { return }
            dismissalPan.isEnabled = pullToDismissEnabled
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        // The reader owns the backdrop, so it stays fixed during dismissal.
        backgroundColor = .clear
        pageImage.contentMode = .scaleAspectFit
        addSubview(pageImage)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        pageTap = tap
        addGestureRecognizer(tap)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        zoomTap = doubleTap
        addGestureRecognizer(doubleTap)
        updateTapGestures()
        let dismissal = UIPanGestureRecognizer(target: self, action: #selector(pulledDown(_:)))
        dismissal.maximumNumberOfTouches = 1
        dismissal.delegate = self
        dismissalPan = dismissal
        addGestureRecognizer(dismissal)
        panGestureRecognizer.require(toFail: dismissal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage?) {
        guard pageImage.image !== image else { return }
        setZoomScale(1, animated: false)
        pageImage.image = image
        fittedBounds = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedBounds, bounds.width > 0, bounds.height > 0 {
            fittedBounds = bounds.size
            setZoomScale(1, animated: false)
            let size = pageImage.image?.size ?? bounds.size
            let scale = min(bounds.width / max(1, size.width), bounds.height / max(1, size.height))
            pageImage.frame = CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale))
            contentSize = pageImage.frame.size
        }
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { pageImage.image == nil ? nil : pageImage }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        updatePanning()
        zoomChanged?(zoomScale > 1.01)
    }

    private func centerImage() {
        pageImage.center = CGPoint(x: max(bounds.width, contentSize.width) / 2, y: max(bounds.height, contentSize.height) / 2)
        // Let the top/bottom of a zoomed page rest near the screen center,
        // rather than allowing only temporary rubber-band overscroll.
        let verticalMargin = zoomScale > 1.01 ? bounds.height / 2 : 0
        let insets = UIEdgeInsets(top: verticalMargin, left: 0, bottom: verticalMargin, right: 0)
        if contentInset != insets { contentInset = insets }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard pageTurnMode == .tap, zoomScale <= 1.01, !isZooming else { return }
        let x = gesture.location(in: self).x - bounds.minX
        turnPage?(x < bounds.width / 2 ? -1 : 1)
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        guard pageTurnMode.usesSwipePaging, doubleTapZoomEnabled,
              pageImage.image != nil, !isZooming else { return }
        if zoomScale > 1.01 {
            setZoomScale(1, animated: true)
        } else {
            let scale = min(maximumZoomScale, 2.5)
            let point = gesture.location(in: pageImage)
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                width: size.width, height: size.height), animated: true)
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissalPan else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        guard pullToDismissEnabled else { return false }
        let velocity = dismissalPan.velocity(in: window)
        return dismissalEnded != nil && zoomScale <= 1.01 && !isZooming
            && velocity.y > 0 && velocity.y > abs(velocity.x) * 1.2
    }

    @objc private func pulledDown(_ gesture: UIPanGestureRecognizer) {
        let distance = max(0, gesture.translation(in: window).y)
        switch gesture.state {
        case .began, .changed: dismissalChanged?(distance)
        case .ended:
            dismissalEnded?(distance > 120 || (distance > 30 && gesture.velocity(in: window).y > 900))
        case .cancelled, .failed: dismissalEnded?(false)
        default: break
        }
    }

    private func updateTapGestures() {
        pageTap.isEnabled = pageTurnMode == .tap
        zoomTap.isEnabled = pageTurnMode.usesSwipePaging && doubleTapZoomEnabled
        // Mutually exclusive: tap-to-turn never waits for a second tap.
    }

    private func updatePanning() {
        // At fit scale, the outer pager owns one-finger drags. Pinch zoom stays
        // available; once enlarged, this scroll view owns image dragging.
        panGestureRecognizer.isEnabled = pageTurnMode == .tap || zoomScale > 1.01
    }
}
