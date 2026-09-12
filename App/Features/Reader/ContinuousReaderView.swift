import NHVCore
import SwiftUI
import UIKit

struct ContinuousReaderView: UIViewRepresentable {
    let pages: [GalleryPage]
    let images: [UIImage?]
    let index: Int
    let resetID: Int
    @Binding var isZoomed: Bool
    var doubleTapZoomEnabled = false
    var isClosing = false
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    let selectPage: (Int) -> Void
    let scrollingChanged: (Bool) -> Void
    let dismissalChanged: (CGFloat) -> Void
    let dismissalEnded: (Bool, CGFloat) -> Void

    func makeUIView(context: Context) -> ContinuousReaderScrollView {
        ContinuousReaderScrollView()
    }

    func updateUIView(_ view: ContinuousReaderScrollView, context: Context) {
        let gapColor: UIColor = theme == .dark ? .black : .white
        view.backgroundColor = gapColor
        view.gapColor = gapColor
        view.isClosing = isClosing
        view.doubleTapZoomEnabled = doubleTapZoomEnabled
        view.selectPage = selectPage
        view.scrollingChanged = scrollingChanged
        view.dismissalChanged = dismissalChanged
        view.dismissalEnded = dismissalEnded
        view.zoomChanged = { zoomed in
            DispatchQueue.main.async {
                if isZoomed != zoomed { isZoomed = zoomed }
            }
        }
        view.update(pages: pages, images: images, index: index, resetID: resetID)
    }
}

final class ContinuousReaderScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    static let pageSpacing: CGFloat = 8

    private let canvas = UIView()
    private var pageSizes: [CGSize] = []
    private var pageViews: [ContinuousReaderPageView] = []
    private var selectedIndex = 0
    private var needsPositioning = true
    private var needsPageLayout = true
    private var lastViewportSize = CGSize.zero
    private var lastResetID: Int?
    private var doubleTap: UITapGestureRecognizer!
    private var dismissalPan: UIPanGestureRecognizer!

    var selectPage: ((Int) -> Void)?
    var scrollingChanged: ((Bool) -> Void)?
    var dismissalChanged: ((CGFloat) -> Void)?
    var dismissalEnded: ((Bool, CGFloat) -> Void)?
    var zoomChanged: ((Bool) -> Void)?
    var doubleTapZoomEnabled = false {
        didSet { doubleTap.isEnabled = doubleTapZoomEnabled }
    }
    var gapColor: UIColor = .black {
        didSet {
            guard oldValue != gapColor else { return }
            canvas.backgroundColor = gapColor
            for page in pageViews { page.indicatorColor = gapColor == .black ? .white : .secondaryLabel }
        }
    }
    var isClosing = false {
        didSet {
            guard oldValue != isClosing else { return }
            if isClosing { isScrollEnabled = false }
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = true
        isDirectionalLockEnabled = true
        backgroundColor = .black
        minimumZoomScale = 1
        maximumZoomScale = 5
        panGestureRecognizer.maximumNumberOfTouches = 1
        canvas.backgroundColor = gapColor
        addSubview(canvas)

        let zoomTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        zoomTap.numberOfTapsRequired = 2
        zoomTap.isEnabled = false
        doubleTap = zoomTap
        addGestureRecognizer(zoomTap)

        let dismissal = UIPanGestureRecognizer(target: self, action: #selector(swipedRight(_:)))
        dismissal.maximumNumberOfTouches = 1
        dismissal.delegate = self
        dismissalPan = dismissal
        addGestureRecognizer(dismissal)
        panGestureRecognizer.require(toFail: dismissal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(pages: [GalleryPage], images: [UIImage?], index: Int, resetID: Int) {
        let sizes = pages.map { CGSize(width: max(1, $0.width), height: max(1, $0.height)) }
        if pageSizes != sizes {
            pageSizes = sizes
            needsPageLayout = true
        }
        synchronizePageViews(count: pages.count)
        for pageIndex in pageViews.indices {
            pageViews[pageIndex].setImage(images.indices.contains(pageIndex) ? images[pageIndex] : nil)
        }
        let safeIndex = min(max(0, index), max(0, pages.count - 1))
        if selectedIndex != safeIndex {
            setZoomScale(1, animated: false)
            zoomChanged?(false)
            selectedIndex = safeIndex
            needsPositioning = true
        }
        if lastResetID != resetID {
            let hadResetID = lastResetID != nil
            lastResetID = resetID
            setZoomScale(1, animated: hadResetID)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let width = bounds.width
        let viewportSize = bounds.size
        let sizeChanged = lastViewportSize != viewportSize
        let widthChanged = lastViewportSize.width != width
        guard needsPageLayout || sizeChanged || needsPositioning else { return }

        if widthChanged, lastViewportSize.width != 0, zoomScale != 1 {
            setZoomScale(1, animated: false)
            zoomChanged?(false)
        }
        lastViewportSize = viewportSize
        needsPageLayout = false
        let firstSize = pageSizes.first ?? CGSize(width: 2, height: 3)
        let firstHeight = width * firstSize.height / max(1, firstSize.width)
        var originY = max(0, (bounds.height - firstHeight) / 2)
        for (index, page) in pageViews.enumerated() {
            let size = pageSizes.indices.contains(index) ? pageSizes[index] : CGSize(width: 2, height: 3)
            let height = width * size.height / max(1, size.width)
            page.frame = CGRect(x: 0, y: originY, width: width, height: height)
            originY += height
            if index < pageViews.count - 1 { originY += Self.pageSpacing }
        }
        canvas.frame = CGRect(x: 0, y: 0, width: width, height: originY)
        contentSize = canvas.bounds.size

        if needsPositioning || sizeChanged {
            needsPositioning = false
            let targetY = selectedIndex == 0
                ? 0
                : (pageViews.indices.contains(selectedIndex) ? pageViews[selectedIndex].frame.minY : 0)
            setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateSelectedPage()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollingChanged?(true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { scrollingChanged?(false) }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollingChanged?(false)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        zoomChanged?(zoomScale > 1.01)
        updateSelectedPage()
    }

    private func updateSelectedPage() {
        guard !needsPositioning, !pageViews.isEmpty, bounds.height > 0 else { return }
        let visibleTop = CGPoint(x: bounds.midX, y: bounds.minY + 1)
        let focusY = convert(visibleTop, to: canvas).y
        var next = min(selectedIndex, pageViews.count - 1)
        while next + 1 < pageViews.count, pageViews[next].frame.maxY < focusY { next += 1 }
        while next > 0, pageViews[next - 1].frame.maxY >= focusY { next -= 1 }
        guard next != selectedIndex else { return }
        selectedIndex = next
        selectPage?(next)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissalPan else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        guard dismissalEnded != nil, !isClosing, zoomScale <= 1.01, !isZooming else { return false }
        let velocity = dismissalPan.velocity(in: window)
        return velocity.x > 0 && velocity.x > abs(velocity.y) * 1.2
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        guard doubleTapZoomEnabled, !isZooming else { return }
        if zoomScale > 1.01 {
            setZoomScale(1, animated: true)
        } else {
            let scale = min(maximumZoomScale, 2.5)
            let point = gesture.location(in: canvas)
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            zoom(to: CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            ), animated: true)
        }
    }

    @objc private func swipedRight(_ gesture: UIPanGestureRecognizer) {
        let distance = max(0, gesture.translation(in: window).x)
        switch gesture.state {
        case .began, .changed:
            dismissalChanged?(distance)
        case .ended:
            let velocity = gesture.velocity(in: window).x
            dismissalEnded?(distance > 120 || (distance > 30 && velocity > 900), bounds.width)
        case .cancelled, .failed:
            dismissalEnded?(false, bounds.width)
        default:
            break
        }
    }

    private func synchronizePageViews(count: Int) {
        while pageViews.count > count {
            pageViews.removeLast().removeFromSuperview()
        }
        while pageViews.count < count {
            let page = ContinuousReaderPageView()
            page.indicatorColor = gapColor == .black ? .white : .secondaryLabel
            pageViews.append(page)
            canvas.addSubview(page)
        }
    }
}

private final class ContinuousReaderPageView: UIView {
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    var indicatorColor: UIColor = .white {
        didSet { spinner.color = indicatorColor }
    }

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        spinner.color = indicatorColor
        spinner.isUserInteractionEnabled = false
        addSubview(spinner)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func setImage(_ image: UIImage?) {
        guard imageView.image !== image else { return }
        imageView.image = image
        if image == nil { spinner.startAnimating() } else { spinner.stopAnimating() }
    }
}
