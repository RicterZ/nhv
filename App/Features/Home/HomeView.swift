import SwiftUI

struct HomeView: View {
    var body: some View {
        ContentUnavailableView("Galleries", systemImage: "books.vertical", description: Text("Browse the latest galleries"))
            .navigationTitle("Home")
    }
}
