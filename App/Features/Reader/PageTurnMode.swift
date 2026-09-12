enum PageTurnMode: String {
    case tap
    case swipe
    case verticalSwipe

    var usesSwipePaging: Bool { self != .tap }
    var scrollsVertically: Bool { self == .verticalSwipe }

    static let storageKey = "reader.pageTurnMode"
    static let doubleTapZoomKey = "reader.doubleTapZoom"
}
