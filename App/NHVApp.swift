import SwiftUI
import NHVCore

@main
struct NHVApp: App {
    var body: some Scene {
        WindowGroup {
            ContentUnavailableView("NHV", systemImage: "book.closed", description: Text("个人阅读客户端"))
        }
    }
}
