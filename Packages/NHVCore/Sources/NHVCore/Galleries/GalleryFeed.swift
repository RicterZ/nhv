import Foundation
import Observation

@MainActor @Observable
public final class GalleryFeed {
    public private(set) var items: [GallerySummary] = []
    public private(set) var isLoading = false
    public private(set) var hasLoaded = false
    public private(set) var hasMore = true
    public private(set) var error: (any Error)?
    public private(set) var retryDate: Date?
    @ObservationIgnored private let load: @Sendable (Int) async throws -> PaginatedResponse<GallerySummary>
    @ObservationIgnored private let willPublish: @MainActor ([GallerySummary]) -> Void
    @ObservationIgnored private var page = 0
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var failedRequest: (page: Int, replacing: Bool)?

    public init(
        load: @escaping @Sendable (Int) async throws -> PaginatedResponse<GallerySummary>,
        willPublish: @escaping @MainActor ([GallerySummary]) -> Void = { _ in }
    ) {
        self.load = load
        self.willPublish = willPublish
    }

    public func loadIfNeeded() async {
        guard !hasLoaded, error == nil else { return }
        await loadNext()
    }

    public func refresh() async {
        await fetch(page: 1, replacing: true)
    }

    public func loadNext() async {
        guard !isLoading, hasMore else { return }
        await fetch(page: page + 1, replacing: false)
    }

    public func retry() async {
        guard !isLoading, let failedRequest else { return }
        await fetch(page: failedRequest.page, replacing: failedRequest.replacing)
    }

    public func cancel() {
        generation = UUID()
        isLoading = false
    }

    private func fetch(page requestedPage: Int, replacing: Bool) async {
        if let retryDate, retryDate > Date() { return }
        let operation = UUID()
        generation = operation
        isLoading = true
        error = nil
        defer { if operation == generation { isLoading = false } }
        do {
            let result = try await load(requestedPage)
            try Task.checkCancellation()
            guard operation == generation else { return }
            var ids = Set(replacing ? [] : items.map(\.id))
            let incoming = result.result.filter { ids.insert($0.id).inserted }
            willPublish(incoming)
            items = replacing ? incoming : items + incoming
            page = requestedPage
            hasMore = requestedPage < result.numPages
            hasLoaded = true
            retryDate = nil
            failedRequest = nil
        } catch is CancellationError {
            return
        } catch {
            guard operation == generation else { return }
            self.error = error
            failedRequest = (requestedPage, replacing)
            if case .rateLimited(let delay) = error as? APIError {
                let seconds = delay ?? 30
                retryDate = Date().addingTimeInterval(seconds.isFinite ? max(1, seconds) : 30)
            }
        }
    }
}
