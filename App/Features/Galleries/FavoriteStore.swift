import Foundation
import Observation
import NHVCore

@MainActor @Observable
final class FavoriteStore {
    struct State {
        let favorited: Bool
        let count: Int?
    }

    private(set) var states: [Int: State] = [:]
    private(set) var updating: Set<Int> = []
    private(set) var revision = 0

    func remember(id: Int, favorited: Bool?, count: Int?) {
        guard let favorited, !updating.contains(id) else { return }
        states[id] = State(favorited: favorited, count: count)
    }

    func set(id: Int, favorited: Bool, api: NHentaiAPI) async throws {
        guard updating.insert(id).inserted else { return }
        defer { updating.remove(id) }
        try await write(id: id, favorited: favorited, api: api)
    }

    func toggle(id: Int, fallbackCount: Int, api: NHentaiAPI) async throws {
        guard updating.insert(id).inserted else { return }
        defer { updating.remove(id) }
        if states[id] == nil {
            let current = try await api.favorite(id: id)
            states[id] = State(favorited: current.favorited, count: current.numFavorites ?? fallbackCount)
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
        states[id] = State(favorited: response.favorited, count: response.numFavorites ?? fallbackCount)
        revision += 1
    }
}
