import SwiftUI
import NHVCore

struct HomeView: View {
    let api: NHentaiAPI
    @Environment(LanguagePreference.self) private var language

    var body: some View {
        GalleryCollectionView(api: api, query: language.applyingFilter(to: .latest))
            .localizedNavigationTitle("Home")
    }
}
