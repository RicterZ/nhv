import Foundation
import Observation

/// Account-specific state, independent of the shared gallery metadata cache.
@MainActor @Observable
public final class FavoriteStore {
    public struct State: Codable, Equatable, Sendable {
        public let favorited: Bool
        public let count: Int?
    }

    public private(set) var states: [Int: State]
    public private(set) var updating: Set<Int> = []
    public private(set) var revision = 0
    public private(set) var syncError: (any Error)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String
    @ObservationIgnored private var versions: [Int: Int] = [:]
    @ObservationIgnored private var syncing = false
    @ObservationIgnored private var lastSync: Date?

    public init(accountID: Int, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        storageKey = "favorites.account.\(accountID)"
        // Read only: constructing SwiftUI state must never write defaults.
        states = defaults.data(forKey: storageKey).flatMap {
            try? JSONDecoder().decode([Int: State].self, from: $0)
        } ?? [:]
    }

    public func version(for id: Int) -> Int { versions[id, default: 0] }

    public func remember(id: Int, favorited: Bool?, count: Int?, expectedVersion: Int) {
        guard version(for: id) == expectedVersion, !updating.contains(id), let favorited else { return }
        update(id: id, favorited: favorited, count: count ?? states[id]?.count)
        persist()
    }

    public func rememberFromFavoritesList(id: Int, count: Int?) {
        // A delayed or cached list must not resurrect a known cancellation.
        // Full synchronization and individual reads reconcile known states.
        guard !updating.contains(id), states[id] == nil else { return }
        states[id] = State(favorited: true, count: count)
        persist()
    }

    public func refresh(id: Int, api: NHentaiAPI) async {
        let expectedVersion = version(for: id)
        guard !updating.contains(id) else { return }
        guard let response = try? await api.favorite(id: id), !Task.isCancelled else { return }
        remember(id: id, favorited: response.favorited, count: response.numFavorites,
            expectedVersion: expectedVersion)
    }

    /// Publish only a complete snapshot. Failed/cancelled pagination never
    /// removes cached favorites, and newer per-gallery changes always win.
    public func synchronize(api: NHentaiAPI, force: Bool = false) async {
        guard !syncing else { return }
        guard force || lastSync.map({ Date().timeIntervalSince($0) >= 60 }) ?? true else { return }
        syncing = true
        syncError = nil
        defer { syncing = false }
        let initialVersions = versions
        let initiallyUpdating = updating
        var snapshot: [Int: Int] = [:]
        do {
            var page = 1
            while true {
                try Task.checkCancellation()
                let response = try await api.favorites(page: page)
                try Task.checkCancellation()
                for item in response.result { snapshot[item.id] = item.numFavorites }
                if page >= response.numPages { break }
                page += 1
            }
            for id in Set(states.keys).union(snapshot.keys) {
                guard !initiallyUpdating.contains(id), !updating.contains(id),
                      version(for: id) == initialVersions[id, default: 0] else { continue }
                update(id: id, favorited: snapshot[id] != nil, count: states[id]?.count ?? snapshot[id])
            }
            persist()
            lastSync = Date()
        } catch is CancellationError {
            return
        } catch {
            syncError = error
        }
    }

    public func set(id: Int, favorited: Bool, api: NHentaiAPI) async throws {
        guard updating.insert(id).inserted else { return }
        versions[id, default: 0] += 1
        defer { updating.remove(id) }
        try await write(id: id, favorited: favorited, api: api)
    }

    public func toggle(id: Int, fallbackCount: Int, api: NHentaiAPI) async throws {
        guard updating.insert(id).inserted else { return }
        versions[id, default: 0] += 1
        defer { updating.remove(id) }
        if states[id] == nil {
            let current = try await api.favorite(id: id)
            update(id: id, favorited: current.favorited, count: current.numFavorites ?? fallbackCount)
            persist()
        }
        guard let current = states[id] else { return }
        try await write(id: id, favorited: !current.favorited, api: api)
    }

    private func write(id: Int, favorited: Bool, api: NHentaiAPI) async throws {
        let previous = states[id]
        let response = try await api.setFavorite(id: id, favorited: favorited)
        let fallbackCount = previous.flatMap { previous in
            previous.count.map { count in
                max(0, count + (previous.favorited == response.favorited ? 0 : (response.favorited ? 1 : -1)))
            }
        }
        update(id: id, favorited: response.favorited, count: response.numFavorites ?? fallbackCount)
        persist()
    }

    private func update(id: Int, favorited: Bool, count: Int?) {
        if states[id]?.favorited != favorited { revision += 1 }
        versions[id, default: 0] += 1
        states[id] = State(favorited: favorited, count: count)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(states), defaults.data(forKey: storageKey) != data else { return }
        defaults.set(data, forKey: storageKey)
    }
}
