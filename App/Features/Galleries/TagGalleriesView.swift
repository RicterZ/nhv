import SwiftUI
import NHVCore

struct TagGalleriesView: View {
    let api: NHentaiAPI
    let tag: Tag
    @State private var sort = GallerySort.date

    var body: some View {
        GalleryCollectionView(api: api, query: .tag(tag.id, sort))
            .navigationTitle(tag.name)
            .toolbar { GallerySortPicker(selection: $sort) }
    }
}
