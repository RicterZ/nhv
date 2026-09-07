import NHVCore
import SwiftUI

@MainActor @Observable
final class LoginPresentation {
    static let travelDuration = 0.6
    static let initialTravelDuration = 0.9
    private static let cycle = 2.4
    private(set) var startedAt = Date()
    private(set) var finishesAt: Date?
    private(set) var isActive = false
    private(set) var startsFromInput = false

    func begin(reduceMotion: Bool = false, fromInput: Bool = false) {
        startsFromInput = fromInput
        let duration = fromInput ? Self.initialTravelDuration : Self.travelDuration
        startedAt = Date().addingTimeInterval(reduceMotion ? 0 : duration)
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

/// One persistent logo moves between the login and error layouts.
struct SessionLogoView: View {
    let showsError: Bool
    @Environment(LoginPresentation.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var destination: Int { showsError ? 2 : (presentation.isActive ? 1 : 0) }

    private var travelAnimation: Animation? {
        guard !reduceMotion else { return nil }
        if destination == 1 && presentation.startsFromInput {
            return .easeOut(duration: LoginPresentation.initialTravelDuration)
        }
        return .easeInOut(duration: LoginPresentation.travelDuration)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let logoSpace = max(0, size.height - 240)
            let centerY = (size.height + geometry.safeAreaInsets.bottom - geometry.safeAreaInsets.top) / 2
            let y = destination == 2 ? 60 : (destination == 1 ? centerY : logoSpace / 2)
            TimelineView(.animation(paused: !presentation.isActive || reduceMotion)) { timeline in
                Image("NHentaiLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: showsError ? 144 : min(240, size.width * 0.55),
                        height: showsError ? 64 : min(120, logoSpace * 0.65)
                    )
                    // Bounce is applied inside the animated placement so its
                    // frames cannot animate the caption or interrupt travel.
                    .offset(y: reduceMotion || showsError ? 0 : presentation.displacement(at: timeline.date))
                    .position(x: size.width / 2, y: y)
                    .animation(travelAnimation, value: destination)
            }
            Text("Signing in…")
                .font(.footnote.weight(.medium))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.55))
                .position(x: size.width / 2, y: max(centerY + 80, size.height - 52))
                .opacity(presentation.isActive && !showsError ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: presentation.isActive && !showsError)
        }
        .ignoresSafeArea(.keyboard)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct SignInView: View {
    let submit: (String) -> Void
    @Environment(SessionStore.self) private var session
    @Environment(LoginPresentation.self) private var presentation
    @State private var apiKey = ""

    @FocusState private var isKeyFocused: Bool
    private let accent = Color(red: 237 / 255, green: 39 / 255, blue: 84 / 255)

    private var isAuthenticating: Bool {
        switch session.phase {
        // Keep the form hidden while this view fades into the restore error.
        case .restoring, .authenticated, .restoreFailed: true
        default: session.isBusy || presentation.isActive
        }
    }

    var body: some View {
        Color.black.ignoresSafeArea()
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
        submit(apiKey)
    }
}
