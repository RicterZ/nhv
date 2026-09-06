import SwiftUI
import NHVCore

struct GallerySortPicker: View {
    @Binding var selection: GallerySort

    var body: some View {
        Picker("Sort", selection: $selection) {
            Text("Newest").tag(GallerySort.date)
            Text("Popular").tag(GallerySort.popular)
            Text("Today").tag(GallerySort.today)
            Text("This Week").tag(GallerySort.week)
            Text("This Month").tag(GallerySort.month)
        }
        .pickerStyle(.menu)
    }
}
