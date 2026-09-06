import SwiftUI
import NHVCore

struct GallerySortPicker: View {
    @Binding var selection: GallerySort

    var body: some View {
        Menu {
            options.pickerStyle(.inline)
        } label: {
            Label("Sort", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Sort"))
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
