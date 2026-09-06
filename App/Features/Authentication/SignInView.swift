import NHVCore
import SwiftUI

enum LoginPresentation {
    static let minimumDuration: Duration = .seconds(2.4)
}

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var apiKey = ""
    @State private var animationStart = Date()
    @State private var isSubmitting = false

    @FocusState private var isKeyFocused: Bool
    private let accent = Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)

    private var isAuthenticating: Bool {
        switch session.phase {
        case .restoring, .authenticated: true
        default: session.isBusy || isSubmitting
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(paused: !isAuthenticating || reduceMotion)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(animationStart)
                    let displacement = isAuthenticating && !reduceMotion ? -10 * sin(elapsed * .pi / 1.2) : 0
                    Image("NHentaiLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(240, geometry.size.width * 0.55), height: min(120, geometry.size.height * 0.22))
                        .offset(y: displacement)
                        .accessibilityHidden(true)
                        .overlay(alignment: .bottom) {
                            Text("Signing in…")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .offset(y: 40)
                                .opacity(isAuthenticating ? 1 : 0)
                                .accessibilityHidden(!isAuthenticating)
                        }
                        .position(x: geometry.size.width / 2, y: max(80, (geometry.size.height - 240) / 2))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottom) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("API Key")
                        .textCase(.uppercase)
                        .font(.caption2.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)

                    SecureField(
                        "API Key", text: $apiKey,
                        prompt: Text("Paste your API key")
                            .foregroundStyle(Color.white.opacity(0.4))
                    )
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

                ScrollView {
                    if let error = session.error {
                        InlineErrorView(error: error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: 56)

                Button(action: signIn) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy)
                .accessibilityIdentifier("signIn.submit")
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
            .opacity(isAuthenticating ? 0 : 1)
            .allowsHitTesting(!isAuthenticating)
            .accessibilityHidden(isAuthenticating)
        }
        .onChange(of: isAuthenticating) { _, active in
            if active { animationStart = Date() }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private func signIn() {
        guard !isAuthenticating else { return }
        isKeyFocused = false
        isSubmitting = true
        Task {
            await session.signIn(key: apiKey)
            if case .authenticated = session.phase {
                apiKey = ""
            } else {
                // Match the successful login's 2.4-second preparation screen.
                try? await Task.sleep(for: LoginPresentation.minimumDuration)
            }
            isSubmitting = false
        }
    }
}
