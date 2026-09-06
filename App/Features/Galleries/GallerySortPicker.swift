import SwiftUI
import NHVCore

struct GallerySortPicker: View {
    @Binding var selection: GallerySort
    var iconOnly = false

    var body: some View {
        if iconOnly {
            Menu {
                options.pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "line.3.horizontal.decrease")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Sort"))
        } else {
            options.pickerStyle(.menu)
        }
    }

    private var options: some View {
        Picker("Sort", selection: $selection) {
            Text("Newest").tag(GallerySort.date)
            Text("Popular").tag(GallerySort.popular)
            Text("Today").tag(GallerySort.today)
            Text("This Week").tag(GallerySort.week)
            Text("This Month").tag(GallerySort.month)
        }
    }
}
