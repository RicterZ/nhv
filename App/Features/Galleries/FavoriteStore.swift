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
        let response = try await api.setFavorite(id: id, favorited: favorited)
        states[id] = State(favorited: response.favorited, count: response.numFavorites)
        revision += 1
    }
}
