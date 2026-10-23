#if os(visionOS)
    import Foundation
    import SwiftUI

    /// The same provider credentials as mobile Studio; secrets remain in Keychain.
    struct EditorVRVoiceSettings: SwiftUI.View {
        @SwiftUI.State private var provider = MobileAgentProvider.api
        @SwiftUI.State private var model = ""
        @SwiftUI.State private var key = ""
        @SwiftUI.State private var endpoint = MobileSloppyCredentials.defaultAPIURL
        @SwiftUI.State private var message: String?
        @SwiftUI.State private var device: MobileCodexDeviceCode?
        @SwiftUI.State private var login: Task<Void, Never>?
        @SwiftUI.Environment(\.dismiss) private var dismiss
        @SwiftUI.Environment(\.openURL) private var openURL

        var body: some SwiftUI.View {
            SwiftUI.VStack(spacing: 20) {
                SwiftUI.Text(L10n.text("Voice with Ada")).font(.title2)
                SwiftUI.Text(L10n.text("Look at the bubble and pinch to dictate. To activate without hands, enable Dwell Control in Accessibility settings."))
                    .font(.callout).foregroundStyle(.secondary)
                SwiftUI.Picker(L10n.text("Provider"), selection: $provider) {
                    SwiftUI.Text(L10n.text("API")).tag(MobileAgentProvider.api)
                    SwiftUI.Text(L10n.text("Codex")).tag(MobileAgentProvider.codex)
                }.pickerStyle(.segmented)
                SwiftUI.TextField(L10n.text("Model ID"), text: $model).textFieldStyle(.roundedBorder)
                if provider == .api {
                    SwiftUI.SecureField(L10n.text("API key"), text: $key).textFieldStyle(.roundedBorder)
                    SwiftUI.TextField(L10n.text("API URL"), text: $endpoint).textFieldStyle(.roundedBorder)
                } else {
                    if let device {
                        SwiftUI.Text(device.userCode).font(.title.monospaced()).textSelection(.enabled)
                        SwiftUI.Link("Complete sign-in", destination: device.verificationURL)
                    }
                    SwiftUI.Button(MobileCodexCredentialStore.load() == nil ? L10n.text("Sign in to Codex") : L10n.text("Sign in again"), action: signIn)
                        .disabled(login != nil)
                }
                if let message { SwiftUI.Text(message).font(.caption).foregroundStyle(.secondary) }
                SwiftUI.HStack {
                    SwiftUI.Button(L10n.text("Cancel")) { dismiss() }
                    SwiftUI.Spacer()
                    SwiftUI.Button(L10n.text("Save")) {
                        do {
                            try MobileSloppyCredentialStore.save(.init(apiKey: key, model: model.trimmingCharacters(in: .whitespacesAndNewlines), apiURL: endpoint, provider: provider))
                            dismiss()
                        } catch { message = error.localizedDescription }
                    }.disabled(model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (provider == .api ? key.isEmpty : MobileCodexCredentialStore.load() == nil))
                }
            }.padding(28).frame(width: 480)
                .onAppear {
                    if let value = MobileSloppyCredentialStore.load() {
                        provider = value.provider ?? .api
                        model = value.model
                        key = value.apiKey
                        endpoint = value.apiURL
                    }
                }
                .onDisappear {
                    login?.cancel()
                    login = nil
                }
        }

        private func signIn() {
            login = Task { @MainActor in
                defer { login = nil }
                do {
                    let code = try await MobileCodexOAuth.start()
                    device = code
                    openURL(code.verificationURL)
                    let deadline = Date().addingTimeInterval(Double(code.expiresIn))
                    while Date() < deadline {
                        try await Task.sleep(for: .seconds(max(1, code.interval)))
                        if try await MobileCodexOAuth.poll(code) {
                            device = nil
                            message = "Signed in. Choose your model and save."
                            return
                        }
                    }
                    message = "The sign-in code expired. Try again."
                } catch is CancellationError {
                } catch { message = error.localizedDescription }
            }
        }
    }
#endif
