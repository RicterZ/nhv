import NHVCore
import SwiftUI

struct ReaderView: View {
    let galleryID: Int
    let pages: [GalleryPage]
    let api: NHentaiAPI
    @Environment(MediaStore.self) private var media
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var index: Int
    @State private var isZoomed = false
    @State private var resetID = 0
    @State private var dismissalOffset: CGFloat = 0
    @State private var horizontalDismissalOffset: CGFloat = 0
    @State private var isDismissing = false
    @State private var edgeExitOffset: CGFloat = 0
    @State private var isClosingEdge = false
    @State private var isClosingVertically = false
    @State private var closingBackdropOpacity: CGFloat = 1
    @State private var closingControlsOpacity: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reader.hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage(PageTurnMode.storageKey) private var pageTurnMode = PageTurnMode.tap
    @AppStorage(PageTurnMode.doubleTapZoomKey) private var doubleTapZoom = false

    init(destination: AppNavigation.ReaderState, api: NHentaiAPI) {
        galleryID = destination.galleryID
        pages = destination.pages
        self.api = api
        _index = State(initialValue: destination.initialIndex)
    }

    private var urls: [URL?] { pages.map { media.image($0.path, galleryID: galleryID, page: $0.number) } }

    var body: some View {
        ZStack {
            let dismissalDistance = max(abs(dismissalOffset), abs(horizontalDismissalOffset))
            Color.black
                .opacity((1 - min(0.8, dismissalDistance / 400)) * closingBackdropOpacity)
                .ignoresSafeArea()
            readerPages(urls)
                .offset(y: edgeExitOffset)
        }
        .overlay(alignment: .topLeading) {
            Text("\(index + 1) / \(pages.count)")
                .font(.subheadline.monospacedDigit())
                .padding(10)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(16)
                .accessibilityLabel(Text("Page \(index + 1) of \(pages.count)"))
                .opacity(closingControlsOpacity)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
                    .background(.black.opacity(0.65), in: Circle())
            }
            .accessibilityLabel(Text("Close reader"))
            .padding(16)
            .opacity(closingControlsOpacity)
        }
        .overlay(alignment: .bottomTrailing) {
            if isZoomed {
                Button {
                    resetID += 1
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left").frame(width: 44, height: 44)
                        .background(.black.opacity(0.65), in: Circle())
                }
                .accessibilityLabel(Text("Reset zoom"))
                .padding(16)
                .opacity(closingControlsOpacity)
            }
        }
        .offset(x: horizontalDismissalOffset)
        .presentationBackground(.clear)
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityAction(named: Text("Next page")) { turnPage(1) }
        .accessibilityAction(named: Text("Previous page")) { turnPage(-1) }
        .allowsHitTesting(hasSeenTutorial)
        .accessibilityHidden(!hasSeenTutorial)
        .overlay {
            if !hasSeenTutorial {
                ReaderTutorial(pageTurnMode: pageTurnMode) { hasSeenTutorial = true }
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else {
                if pageTurnMode.isContinuous {
                    navigation.updateReaderPage(index)
                    media.reader.trim(around: index, urls: urls)
                }
                media.reader.pause()
                return
            }
            while media.resolver == nil && !Task.isCancelled {
                await media.prepare(api: api)
                if media.resolver == nil {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                }
            }
            guard !Task.isCancelled else { return }
            media.reader.focus(on: index, urls: urls, retainsLoadedImages: pageTurnMode.isContinuous)
        }
        .onChange(of: index) { _, _ in
            if !pageTurnMode.isContinuous { navigation.updateReaderPage(index) }
            media.reader.focus(on: index, urls: urls, retainsLoadedImages: pageTurnMode.isContinuous)
        }
        .onAppear { navigation.isReading = true }
        .onDisappear {
            media.reader.cancel()
            navigation.isReading = false
        }
    }

    @ViewBuilder
    private func readerPages(_ pageURLs: [URL?]) -> some View {
        let images = pageURLs.map { $0.flatMap { media.reader.images[$0] } }
        if pageTurnMode.isContinuous {
            ContinuousReaderView(
                pages: pages,
                images: images,
                index: index,
                resetID: resetID,
                isZoomed: $isZoomed,
                doubleTapZoomEnabled: doubleTapZoom,
                isClosing: isClosingEdge,
                selectPage: selectContinuousPage,
                scrollingChanged: continuousScrollingChanged,
                dismissalChanged: updateHorizontalDismissal,
                dismissalEnded: finishHorizontalDismissal
            )
            .ignoresSafeArea()
        } else if pageTurnMode.usesSwipePaging {
            PagedReaderView(
                images: images,
                index: index,
                resetID: resetID,
                isZoomed: $isZoomed,
                doubleTapZoomEnabled: doubleTapZoom,
                scrollsVertically: pageTurnMode.scrollsVertically,
                isDismissing: isDismissing,
                isClosing: isClosingEdge,
                selectPage: { turnPage($0 - index) },
                dismissalChanged: updateDismissal,
                dismissalEnded: finishDismissal,
                horizontalDismissalChanged: updateHorizontalDismissal,
                horizontalDismissalEnded: finishHorizontalDismissal
            )
            .offset(y: pageTurnMode.scrollsVertically
                ? (isClosingVertically ? dismissalOffset : 0)
                : dismissalOffset)
            .ignoresSafeArea()
        } else {
            let image = images.indices.contains(index) ? images[index] : nil
            ZoomablePage(
                image: image,
                resetID: resetID,
                isZoomed: $isZoomed,
                pageTurnMode: pageTurnMode,
                turnPage: turnPage,
                dismissalChanged: updateDismissal,
                dismissalEnded: finishDismissal
            )
            .offset(y: dismissalOffset)
            .ignoresSafeArea()
            if image == nil {
                ProgressView().tint(.white).allowsHitTesting(false)
            }
        }
    }

    private func updateDismissal(_ distance: CGFloat) {
        isDismissing = distance != 0 || horizontalDismissalOffset != 0
        dismissalOffset = distance
    }

    private func updateHorizontalDismissal(_ distance: CGFloat) {
        guard !isClosingEdge else { return }
        isDismissing = distance != 0 || dismissalOffset != 0
        horizontalDismissalOffset = max(0, distance)
    }

    private func finishDismissal(_ close: Bool, viewportHeight: CGFloat, velocity: CGFloat) {
        if close {
            guard !isClosingEdge else { return }
            isClosingEdge = true
            isClosingVertically = true
            let direction: CGFloat = dismissalOffset < 0 ? -1 : 1
            if reduceMotion {
                dismiss()
            } else {
                let duration = 0.38
                let remainingDistance = max(0, viewportHeight - abs(dismissalOffset))
                let outwardVelocity = max(0, direction * velocity)
                let initialVelocity = min(3, outwardVelocity / max(1, remainingDistance))
                withAnimation(.interpolatingSpring(
                    duration: duration,
                    bounce: 0.05,
                    initialVelocity: initialVelocity
                )) {
                    edgeExitOffset = direction * remainingDistance
                }
                withAnimation(.easeOut(duration: 0.22)) {
                    closingBackdropOpacity = 0
                    closingControlsOpacity = 0
                }
                Task { @MainActor in
                    do { try await Task.sleep(for: .seconds(duration)) } catch { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { dismiss() }
                }
            }
        } else {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
                dismissalOffset = 0
            } completion: {
                // Keep the moving page transparent until the return finishes.
                if dismissalOffset == 0, horizontalDismissalOffset == 0 { isDismissing = false }
            }
        }
    }

    private func finishHorizontalDismissal(_ close: Bool, viewportWidth: CGFloat) {
        if close {
            guard !isClosingEdge else { return }
            isClosingEdge = true
            if reduceMotion {
                dismiss()
            } else {
                let duration = 0.26
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: duration)) {
                    horizontalDismissalOffset = max(horizontalDismissalOffset, viewportWidth)
                }
                Task { @MainActor in
                    do { try await Task.sleep(for: .seconds(duration)) } catch { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { dismiss() }
                }
            }
        } else {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
                horizontalDismissalOffset = 0
            } completion: {
                if dismissalOffset == 0, horizontalDismissalOffset == 0 { isDismissing = false }
            }
        }
    }

    private func selectContinuousPage(_ page: Int) {
        guard pages.indices.contains(page), page != index else { return }
        index = page
    }

    private func continuousScrollingChanged(_ scrolling: Bool) {
        guard !scrolling else { return }
        navigation.updateReaderPage(index)
        media.reader.trim(around: index, urls: urls)
    }

    private func turnPage(_ delta: Int) {
        guard hasSeenTutorial else { return }
        let next = index + delta
        guard pages.indices.contains(next) else { return }
        isZoomed = false
        resetID += 1
        index = next
    }
}
