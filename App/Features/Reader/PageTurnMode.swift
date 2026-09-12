enum PageTurnMode: String {
    case tap
    case swipe
    case verticalSwipe
    case continuous

    var usesSwipePaging: Bool { self == .swipe || self == .verticalSwipe }
    var scrollsVertically: Bool { self == .verticalSwipe }
    var isContinuous: Bool { self == .continuous }
    var supportsDoubleTapZoom: Bool { self != .tap }

    static let storageKey = "reader.pageTurnMode"
    static let doubleTapZoomKey = "reader.doubleTapZoom"
}
