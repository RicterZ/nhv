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
                }

                Section {
                    Button(action: signIn) {
                        Group {
                            if session.isBusy {
                                ProgressView("Signing in…")
                            } else {
                                Text("Sign In")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy)
                    .accessibilityIdentifier("signIn.submit")
                }
                .listRowBackground(Color.clear)

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
