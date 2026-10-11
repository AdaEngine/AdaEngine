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
                SwiftUI.Text("Voice with Ada").font(.title2)
                SwiftUI.Text("Look at the bubble and pinch to dictate. To activate without hands, enable Dwell Control in Accessibility settings.")
                    .font(.callout).foregroundStyle(.secondary)
                SwiftUI.Picker("Provider", selection: $provider) {
                    SwiftUI.Text("API").tag(MobileAgentProvider.api)
                    SwiftUI.Text("Codex").tag(MobileAgentProvider.codex)
                }.pickerStyle(.segmented)
                SwiftUI.TextField("Model ID", text: $model).textFieldStyle(.roundedBorder)
                if provider == .api {
                    SwiftUI.SecureField("API key", text: $key).textFieldStyle(.roundedBorder)
                    SwiftUI.TextField("API URL", text: $endpoint).textFieldStyle(.roundedBorder)
                } else {
                    if let device {
                        SwiftUI.Text(device.userCode).font(.title.monospaced()).textSelection(.enabled)
                        SwiftUI.Link("Complete sign-in", destination: device.verificationURL)
                    }
                    SwiftUI.Button(MobileCodexCredentialStore.load() == nil ? "Sign in to Codex" : "Sign in again", action: signIn)
                        .disabled(login != nil)
                }
                if let message { SwiftUI.Text(message).font(.caption).foregroundStyle(.secondary) }
                SwiftUI.HStack {
                    SwiftUI.Button("Cancel") { dismiss() }
                    SwiftUI.Spacer()
                    SwiftUI.Button("Save") {
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
