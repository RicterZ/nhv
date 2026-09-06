import SwiftUI
import NHVCore

struct HomeView: View {
    let api: NHentaiAPI

    var body: some View {
        GalleryCollectionView(api: api, query: .latest)
            .navigationTitle("Home")
    }
}
