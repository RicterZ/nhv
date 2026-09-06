import SwiftUI
import NHVCore

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                        .disabled(session.isBusy)
                        .accessibilityIdentifier("signIn.apiKey")
                    Button(action: signIn) {
                        if session.isBusy {
                            ProgressView("Signing in…")
                        } else {
                            Text("Sign In")
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy)
                    .accessibilityIdentifier("signIn.submit")
                } header: {
                    Text("Your personal reader")
                } footer: {
                    Text("Create an API key in your account settings. Your key is stored securely on this device.")
                }

                if let error = session.error {
                    Section { InlineErrorView(error: error) }
                }
            }
            .navigationTitle("NHV")
        }
    }

    private func signIn() {
        guard !session.isBusy else { return }
        Task {
            await session.signIn(key: apiKey)
            if case .authenticated = session.phase { apiKey = "" }
        }
    }
}
