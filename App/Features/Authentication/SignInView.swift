import NHVCore
import SwiftUI

@MainActor @Observable
final class LoginPresentation {
    private static let cycle = 2.4
    private(set) var startedAt = Date()
    private(set) var finishesAt: Date?
    private(set) var isActive = false

    func begin() {
        startedAt = Date()
        finishesAt = nil
        isActive = true
    }

    func displacement(at date: Date) -> Double {
        guard isActive else { return 0 }
        if let finishesAt, date >= finishesAt { return 0 }
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        // Zero displacement and velocity at both ends of every cycle.
        return -10 * (1 - cos(2 * .pi * elapsed / Self.cycle))
    }

    func finish() async throws {
        let start = startedAt
        let elapsed = max(0, Date().timeIntervalSince(start))
        let cycles = max(1, ceil(elapsed / Self.cycle))
        let end = start.addingTimeInterval(cycles * Self.cycle)
        finishesAt = end
        // Hold the resting frame briefly before replacing the screen.
        try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow) + 0.12))
        guard startedAt == start else { return }
        isActive = false
    }
}

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LoginPresentation.self) private var presentation
    @State private var apiKey = ""
    @State private var isSubmitting = false

    @FocusState private var isKeyFocused: Bool
    private let accent = Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)

    private var isAuthenticating: Bool {
        switch session.phase {
        case .restoring, .authenticated: true
        default: session.isBusy || isSubmitting || presentation.isActive
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(paused: !isAuthenticating || reduceMotion)) { timeline in
                    let displacement = reduceMotion ? 0 : presentation.displacement(at: timeline.date)
                    Image("NHentaiLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(240, geometry.size.width * 0.55), height: min(120, geometry.size.height * 0.22))
                        .offset(y: displacement)
                        .accessibilityHidden(true)
                        .overlay(alignment: .bottom) {
                            Text("Signing in…")
                                .font(.footnote.weight(.medium))
                                .tracking(0.5)
                                .foregroundStyle(.white.opacity(0.55))
                                .offset(y: 36)
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
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private func signIn() {
        guard !isAuthenticating else { return }
        isKeyFocused = false
        presentation.begin()
        isSubmitting = true
        Task {
            await session.signIn(key: apiKey)
            if case .authenticated = session.phase {
                apiKey = ""
            } else {
                try? await presentation.finish()
            }
            isSubmitting = false
        }
    }
}
