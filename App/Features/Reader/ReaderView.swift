import NHVCore
import SwiftUI

struct ReaderDestination: Identifiable {
    let id = UUID()
    let galleryID: Int
    let pages: [GalleryPage]
    let initialIndex: Int
}

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
    @AppStorage("reader.hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage(PageTurnMode.storageKey) private var pageTurnMode = PageTurnMode.tap
    @AppStorage(PageTurnMode.doubleTapZoomKey) private var doubleTapZoom = false

    init(destination: ReaderDestination, api: NHentaiAPI) {
        galleryID = destination.galleryID
        pages = destination.pages
        self.api = api
        _index = State(initialValue: destination.initialIndex)
    }

    private var urls: [URL?] { pages.map { media.image($0.path, galleryID: galleryID, page: $0.number) } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            let pageURLs = urls
            let url = pageURLs.indices.contains(index) ? pageURLs[index] : nil
            if pageTurnMode == .swipe {
                PagedReaderView(images: pageURLs.map { $0.flatMap { media.reader.images[$0] } },
                    index: index, resetID: resetID, isZoomed: $isZoomed,
                    doubleTapZoomEnabled: doubleTapZoom,
                    selectPage: { turnPage($0 - index) })
                    .ignoresSafeArea()
            } else {
                ZoomablePage(image: url.flatMap { media.reader.images[$0] }, resetID: resetID, isZoomed: $isZoomed,
                    pageTurnMode: pageTurnMode, turnPage: turnPage)
                    .ignoresSafeArea()
                if url.flatMap({ media.reader.images[$0] }) == nil {
                    ProgressView().tint(.white).allowsHitTesting(false)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Text("\(index + 1) / \(pages.count)")
                .font(.subheadline.monospacedDigit())
                .padding(10)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(16)
                .accessibilityLabel(Text("Page \(index + 1) of \(pages.count)"))
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
            }
        }
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
            media.reader.focus(on: index, urls: urls)
        }
        .onChange(of: index) { _, _ in media.reader.focus(on: index, urls: urls) }
        .onAppear { navigation.isReading = true }
        .onDisappear {
            media.reader.cancel()
            navigation.isReading = false
        }
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
