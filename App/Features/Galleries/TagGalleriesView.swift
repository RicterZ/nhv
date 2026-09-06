import SwiftUI
import NHVCore

struct TagGalleriesView: View {
    let api: NHentaiAPI
    let tag: Tag
    @State private var sort = GallerySort.date

    var body: some View {
        GalleryBrowsePage(title: Text(verbatim: tag.name), sort: $sort) {
            GalleryCollectionView(api: api, query: .tag(tag.id, sort))
        }
    }
}
