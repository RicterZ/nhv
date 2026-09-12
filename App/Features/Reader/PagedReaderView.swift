import SwiftUI
import UIKit

struct PagedReaderView: UIViewRepresentable {
    let images: [UIImage?]
    let index: Int
    let resetID: Int
    @Binding var isZoomed: Bool
    var doubleTapZoomEnabled = false
    var scrollsVertically = false
    var isDismissing = false
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    let selectPage: (Int) -> Void
    var dismissalChanged: ((CGFloat) -> Void)?
    var dismissalEnded: ((Bool) -> Void)?

    func makeUIView(context: Context) -> ReaderPagerViewport { ReaderPagerViewport() }

    func updateUIView(_ viewport: ReaderPagerViewport, context: Context) {
        let view = viewport.pager
        // Reader controls stay dark; the space between pages follows app theme.
        let gapColor: UIColor = theme == .dark ? .black : .white
        viewport.backgroundColor = isDismissing ? .clear : gapColor
        view.backgroundColor = isDismissing ? .clear : gapColor
        view.isDismissing = isDismissing
        viewport.scrollsVertically = scrollsVertically
        view.scrollsVertically = scrollsVertically
        view.dismissalChanged = dismissalChanged
        view.dismissalEnded = dismissalEnded
        view.selectPage = selectPage
        view.doubleTapZoomEnabled = doubleTapZoomEnabled
        view.zoomChanged = { zoomed in
            DispatchQueue.main.async {
                if isZoomed != zoomed { isZoomed = zoomed }
            }
        }
        view.update(images: images, index: index, resetID: resetID)
    }
}

/// The native paging stride includes a gutter outside the visible viewport.
/// Each image still fills the viewport on its non-paging axis when at rest.
final class ReaderPagerViewport: UIView {
    let pager = ReaderPagingView()
    var scrollsVertically = false {
        didSet {
            guard oldValue != scrollsVertically else { return }
            setNeedsLayout()
        }
    }

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = .black
        addSubview(pager)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        pager.frame = scrollsVertically
            ? CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height + ReaderPagingView.pageSpacing)
            : CGRect(x: 0, y: 0, width: bounds.width + ReaderPagingView.pageSpacing, height: bounds.height)
    }
}

/// Native paging supplies tracking, velocity, deceleration, and edge bounce.
/// Only the current page and its two neighbors have zoomable views.
final class ReaderPagingView: UIScrollView, UIScrollViewDelegate {
    static let pageSpacing: CGFloat = 20
    private var images: [UIImage?] = []
    private var pages: [Int: ReaderPageContainer] = [:]
    private var selectedIndex = 0
    private var lastResetID: Int?
    private var lastSize = CGSize.zero
    var selectPage: ((Int) -> Void)?
    var dismissalChanged: ((CGFloat) -> Void)?
    var dismissalEnded: ((Bool) -> Void)?
    var zoomChanged: ((Bool) -> Void)?
    var scrollsVertically = false {
        didSet {
            guard oldValue != scrollsVertically else { return }
            lastSize = .zero
            for page in pages.values { page.scroll.pullToDismissEnabled = !scrollsVertically }
            updateIndicators()
            setNeedsLayout()
        }
    }
    var isDismissing = false {
        didSet {
            guard oldValue != isDismissing else { return }
            for page in pages.values {
                page.scroll.backgroundColor = isDismissing ? .clear : .black
            }
        }
    }
    var doubleTapZoomEnabled = false {
        didSet {
            for page in pages.values { page.scroll.doubleTapZoomEnabled = doubleTapZoomEnabled }
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        isPagingEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .black
        panGestureRecognizer.maximumNumberOfTouches = 1
        updateIndicators()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(images: [UIImage?], index: Int, resetID: Int) {
        self.images = images
        if selectedIndex != index {
            pages[selectedIndex]?.scroll.setZoomScale(1, animated: false)
            selectedIndex = index
            isScrollEnabled = true
            zoomChanged?(false)
            setContentOffset(offset(for: index), animated: false)
        }
        updatePages()
        if lastResetID != resetID {
            lastResetID = resetID
            pages[selectedIndex]?.scroll.setZoomScale(1, animated: true)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        contentSize = scrollsVertically
            ? CGSize(width: size.width, height: size.height * CGFloat(images.count))
            : CGSize(width: size.width * CGFloat(images.count), height: size.height)
        for (index, page) in pages {
            page.frame = scrollsVertically
                ? CGRect(x: 0, y: CGFloat(index) * size.height,
                    width: size.width, height: max(0, size.height - Self.pageSpacing))
                : CGRect(x: CGFloat(index) * size.width, y: 0,
                    width: max(0, size.width - Self.pageSpacing), height: size.height)
        }
        if lastSize != size {
            lastSize = size
            setContentOffset(offset(for: selectedIndex), animated: false)
        }
    }

    private func updatePages() {
        let wanted = Set((selectedIndex - 1...selectedIndex + 1).filter { images.indices.contains($0) })
        for index in Array(pages.keys) where !wanted.contains(index) {
            pages.removeValue(forKey: index)?.removeFromSuperview()
        }
        for index in wanted {
            let page: ReaderPageContainer
            if let existing = pages[index] { page = existing }
            else {
                page = ReaderPageContainer()
                page.scroll.zoomChanged = { [weak self] zoomed in
                    guard let self, self.selectedIndex == index else { return }
                    self.isScrollEnabled = !zoomed
                    self.zoomChanged?(zoomed)
                }
                page.scroll.dismissalChanged = { [weak self] distance in self?.dismissalChanged?(distance) }
                page.scroll.dismissalEnded = { [weak self] close in self?.dismissalEnded?(close) }
                panGestureRecognizer.require(toFail: page.scroll.dismissalPan)
                pages[index] = page
                addSubview(page)
            }
            page.setImage(images[index])
            page.scroll.backgroundColor = isDismissing ? .clear : .black
            page.scroll.doubleTapZoomEnabled = doubleTapZoomEnabled
            page.scroll.pullToDismissEnabled = !scrollsVertically
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { finishPaging() }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { finishPaging() }
    }

    private func finishPaging() {
        let stride = scrollsVertically ? bounds.height : bounds.width
        guard stride > 0, !images.isEmpty else { return }
        let position = scrollsVertically ? contentOffset.y : contentOffset.x
        let next = min(images.count - 1, max(0, Int((position / stride).rounded())))
        guard next != selectedIndex else { return }
        pages[selectedIndex]?.scroll.setZoomScale(1, animated: false)
        selectedIndex = next
        updatePages()
        setNeedsLayout()
        isScrollEnabled = true
        zoomChanged?(false)
        selectPage?(next)
    }

    private func offset(for index: Int) -> CGPoint {
        scrollsVertically
            ? CGPoint(x: 0, y: CGFloat(index) * bounds.height)
            : CGPoint(x: CGFloat(index) * bounds.width, y: 0)
    }

    private func updateIndicators() {
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceHorizontal = !scrollsVertically
        alwaysBounceVertical = scrollsVertically
    }
}

private final class ReaderPageContainer: UIView {
    let scroll = PageScrollView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        scroll.pageTurnMode = .swipe
        addSubview(scroll)
        spinner.color = .white
        spinner.isUserInteractionEnabled = false
        addSubview(spinner)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        scroll.frame = bounds
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func setImage(_ image: UIImage?) {
        scroll.setImage(image)
        if image == nil { spinner.startAnimating() } else { spinner.stopAnimating() }
    }
}
