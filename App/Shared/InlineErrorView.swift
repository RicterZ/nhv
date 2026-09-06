import SwiftUI

struct InlineErrorView: View {
    let error: any Error

    var body: some View {
        Label(ErrorMessage.text(for: error), systemImage: "exclamationmark.circle")
            .foregroundStyle(.red)
            .font(.callout)
            .accessibilityIdentifier("error.message")
    }
}
