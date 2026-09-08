import SwiftUI
import UIKit

struct PagedReaderView: UIViewRepresentable {
    let images: [UIImage?]
    let index: Int
    let resetID: Int
    @Binding var isZoomed: Bool
    var doubleTapZoomEnabled = false
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    let selectPage: (Int) -> Void

    func makeUIView(context: Context) -> ReaderPagerViewport { ReaderPagerViewport() }

    func updateUIView(_ viewport: ReaderPagerViewport, context: Context) {
        let view = viewport.pager
        // Reader controls stay dark; the space between pages follows app theme.
        let gapColor: UIColor = theme == .dark ? .black : .white
        viewport.backgroundColor = gapColor
        view.backgroundColor = gapColor
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
/// Each image still gets the full screen width when its page is at rest.
final class ReaderPagerViewport: UIView {
    let pager = ReaderPagingView()

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = .black
        addSubview(pager)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        pager.frame = CGRect(x: 0, y: 0, width: bounds.width + ReaderPagingView.pageSpacing, height: bounds.height)
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
    var zoomChanged: ((Bool) -> Void)?
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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(images: [UIImage?], index: Int, resetID: Int) {
        self.images = images
        if selectedIndex != index {
            pages[selectedIndex]?.scroll.setZoomScale(1, animated: false)
            selectedIndex = index
            isScrollEnabled = true
            zoomChanged?(false)
            setContentOffset(CGPoint(x: CGFloat(index) * bounds.width, y: 0), animated: false)
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
        contentSize = CGSize(width: size.width * CGFloat(images.count), height: size.height)
        for (index, page) in pages {
            page.frame = CGRect(x: CGFloat(index) * size.width, y: 0,
                width: max(0, size.width - Self.pageSpacing), height: size.height)
        }
        if lastSize != size {
            lastSize = size
            setContentOffset(CGPoint(x: CGFloat(selectedIndex) * size.width, y: 0), animated: false)
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
                pages[index] = page
                addSubview(page)
            }
            page.setImage(images[index])
            page.scroll.doubleTapZoomEnabled = doubleTapZoomEnabled
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { finishPaging() }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { finishPaging() }
    }

    private func finishPaging() {
        guard bounds.width > 0, !images.isEmpty else { return }
        let next = min(images.count - 1, max(0, Int((contentOffset.x / bounds.width).rounded())))
        guard next != selectedIndex else { return }
        pages[selectedIndex]?.scroll.setZoomScale(1, animated: false)
        selectedIndex = next
        updatePages()
        setNeedsLayout()
        isScrollEnabled = true
        zoomChanged?(false)
        selectPage?(next)
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
