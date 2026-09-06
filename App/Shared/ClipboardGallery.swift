import UIKit
import NHVCore

@MainActor
enum ClipboardGallery {
    static let enabledKey = "clipboard.readEnabled"
    private static let handledChangeKey = "clipboard.handledChangeCount"

    struct Link {
        let galleryID: Int
        fileprivate let changeCount: Int
    }

    static func nextGallery() -> Link? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: enabledKey) == nil || defaults.bool(forKey: enabledKey) else { return nil }
        let pasteboard = UIPasteboard.general
        let change = pasteboard.changeCount
        guard defaults.object(forKey: handledChangeKey) == nil || defaults.integer(forKey: handledChangeKey) != change else { return nil }
        // Mark before reading: the system paste permission prompt can change
        // scene activity. Returning from it must not recursively read again.
        defaults.set(change, forKey: handledChangeKey)
        guard let text = pasteboard.string,
              pasteboard.changeCount == change,
              let id = GalleryLink.id(in: text) else { return nil }
        return Link(galleryID: id, changeCount: change)
    }

    static func clearAfterOpening(_ link: Link) {
        let pasteboard = UIPasteboard.general
        // Never clear something copied after we read the gallery link.
        guard pasteboard.changeCount == link.changeCount else { return }
        pasteboard.items = []
        ignoreCurrentContent()
    }

    static func ignoreCurrentContent() {
        UserDefaults.standard.set(UIPasteboard.general.changeCount, forKey: handledChangeKey)
    }
}
