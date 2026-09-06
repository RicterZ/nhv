import SwiftUI

struct GalleryTitleLabel: View {
    let title: String
    let tagIDs: [Int]
    @Environment(GalleryLanguageStore.self) private var store
    @Environment(\.locale) private var locale

    var body: some View {
        let languages = store.languages(for: tagIDs)
        let flags = languages.map(\.flag).joined(separator: " ")
        Text(verbatim: flags.isEmpty ? title : "\(flags) \(title)")
            .accessibilityLabel((languages.map { locale.localizedString(forLanguageCode: $0.code) ?? $0.code } + [title]).joined(separator: ", "))
    }
}
