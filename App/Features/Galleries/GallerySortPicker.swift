import SwiftUI
import NHVCore

struct GallerySortPicker: View {
    @Binding var selection: GallerySort
    var usesChipStyle = false

    var body: some View {
        Menu {
            options.pickerStyle(.inline)
        } label: {
            if usesChipStyle {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                    selectionTitle
                }
                .modifier(GalleryFilterChipStyle())
            } else {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Sort"))
    }

    private var selectionTitle: Text {
        switch selection {
        case .date: Text("Newest")
        case .popular: Text("Popular")
        case .today: Text("Today")
        case .week: Text("This Week")
        case .month: Text("This Month")
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
