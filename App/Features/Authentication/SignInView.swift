import SwiftUI
import NHVCore

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @State private var apiKey = ""

    @FocusState private var isKeyFocused: Bool
    private let accent = Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("NHentaiLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(240, geometry.size.width * 0.55), height: min(120, geometry.size.height * 0.22))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("API Key")
                                .textCase(.uppercase)
                                .font(.caption2.weight(.semibold))
                                .tracking(2.5)
                                .foregroundStyle(accent)
                                .accessibilityHidden(true)

                            SecureField("API Key", text: $apiKey, prompt: Text("Paste your API key")
                                .foregroundStyle(Color.white.opacity(0.4)))
                                .font(.system(.body, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .submitLabel(.go)
                                .focused($isKeyFocused)
                                .onSubmit(signIn)
                                .disabled(session.isBusy)
                                .frame(minHeight: 52)
                                .tint(accent)
                                .accessibilityIdentifier("signIn.apiKey")

                            Rectangle()
                                .fill(isKeyFocused ? accent : Color.white.opacity(0.24))
                                .frame(height: 1)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(accent)
                                        .frame(width: 28, height: 2)
                                }
                        }
                        .animation(.easeOut(duration: 0.18), value: isKeyFocused)

                        if let error = session.error {
                            InlineErrorView(error: error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: signIn) {
                            Group {
                                if session.isBusy {
                                    ProgressView("Signing in…")
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy)
                        .accessibilityIdentifier("signIn.submit")
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private func signIn() {
        guard !session.isBusy else { return }
        Task {
            await session.signIn(key: apiKey)
            if case .authenticated = session.phase { apiKey = "" }
        }
    }
}
