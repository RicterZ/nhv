import SwiftUI
import NHVCore

struct SessionErrorView: View {
    let error: (any Error)?
    let retry: () -> Void
    let useAnotherKey: () -> Void

    private let accent = Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var content: some View {
        VStack(spacing: 0) {
            // RootView owns the logo so it can move here without being replaced.
            Color.clear
                .frame(height: 64)
                .accessibilityHidden(true)

            Spacer(minLength: 40)

            VStack(spacing: 20) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(accent)
                    .frame(width: 88, height: 88)
                    .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 26))
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Unable to restore session")
                        .font(.title2.weight(.semibold))
                    if let error {
                        Text(ErrorMessage.text(for: error))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .lineSpacing(4)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 320)
            .accessibilityIdentifier("session.error")

            Spacer(minLength: 48)

            VStack(spacing: 12) {
                Button(action: retry) {
                    Text("Try Again")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(accent, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("session.retry")

                Button(action: useAnotherKey) {
                    Text("Use Another API Key")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }
}
