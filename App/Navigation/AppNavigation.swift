import Foundation
import Observation

@MainActor @Observable
final class AppNavigation {
    enum Tab: Hashable {
        case home, search, favorites, settings
    }

    var selectedTab = Tab.home
    var homePath: [Int] = []
    var isReading = false

    func openGallery(id: Int) {
        if selectedTab == .home, homePath.last == id { return }
        homePath = [id]
        selectedTab = .home
    }
}
