#if os(iOS) || os(Android)
import Foundation
import Observation

@Observable
@MainActor
final class MobileEditorProviderModelStore {
    var apiURL: String {
        didSet {
            guard apiURL != oldValue, provider == .api else {
                return
            }
            cancel()
            models = []
            modelID = ""
            errorMessage = "Load models for the updated API URL."
        }
    }
    var apiKey: String {
        didSet {
            guard apiKey != oldValue, provider == .api else {
                return
            }
            cancel()
            models = []
            modelID = ""
        }
    }
    private(set) var provider: MobileAgentProvider
    private(set) var modelID: String
    private(set) var selectedProvider: MobileAgentProvider
    private(set) var selectedModelID: String
    private(set) var selectedTitle: String
    private(set) var models: [EditorProviderModel] = []
    private(set) var isLoading = false
    private(set) var errorMessage = ""
    private var task: Task<Void, Never>?
    private var requestID = UUID()

    init() {
        let credentials = MobileSloppyCredentialStore.load() ?? MobileSloppyCredentials()
        apiURL = credentials.apiURL
        apiKey = credentials.apiKey
        modelID = credentials.model
        let initialProvider = credentials.provider ?? (MobileCodexCredentialStore.load() != nil ? .codex : credentials.apiKey.isEmpty ? .ada : .api)
        provider = initialProvider
        selectedProvider = initialProvider
        selectedModelID = credentials.model
        selectedTitle = credentials.model
        if initialProvider == .ada { modelID = Self.cloudModel.id; selectedModelID = modelID; selectedTitle = Self.cloudModel.title; models = [Self.cloudModel] }
    }

    static let cloudModel = EditorProviderModel(id: "qwen/qwen3-coder-next", title: "Coder Next")
    @discardableResult func useCloudAI() -> Bool {
        switchProvider(to: .ada)
        modelID = Self.cloudModel.id; models = [Self.cloudModel]; errorMessage = ""
        return save()
    }
    func reportCloudError(_ message: String) { errorMessage = message }
    var providerTitle: String { provider == .ada ? "Ada AI · Cloud Pro" : provider == .codex ? "Codex" : "API key" }
    var selectedProviderTitle: String { selectedProvider == .ada ? "Ada AI · Cloud Pro" : selectedProvider == .codex ? "Codex" : "API key" }
    var isCodexConnected: Bool { MobileCodexCredentialStore.load() != nil }

    func switchProvider(to selected: MobileAgentProvider) {
        guard provider != selected else {
            return
        }
        cancel()
        provider = selected
        modelID = ""
        models = []
        errorMessage = ""
    }

    func beginSelection() {
        switchProvider(to: selectedProvider)
        modelID = selectedModelID
    }

    @discardableResult
    func save() -> Bool {
        do {
            if provider == .api {
                _ = try EditorProviderModelCatalog.apiRequest(baseURL: apiURL, apiKey: apiKey)
            }
            try MobileSloppyCredentialStore.save(MobileSloppyCredentials(
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                model: modelID,
                apiURL: apiURL.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: provider
            ))
            selectedProvider = provider
            selectedModelID = modelID
            selectedTitle = models.first { $0.id == modelID }?.title ?? modelID
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func select(_ model: EditorProviderModel) -> Bool {
        guard models.contains(where: { $0.id == model.id }) else {
            return false
        }
        let previous = modelID
        modelID = model.id
        guard save() else {
            modelID = previous
            return false
        }
        return true
    }

    func cancel() {
        task?.cancel()
        task = nil
        requestID = UUID()
        isLoading = false
    }

    func reload() {
        if provider == .ada { models = [Self.cloudModel]; modelID = Self.cloudModel.id; errorMessage = ""; return }
        cancel()
        let generation = requestID
        let providerForRequest = provider
        let key = apiKey
        let baseURL = apiURL
        errorMessage = ""
        guard providerForRequest == .codex ? isCodexConnected : !key.isEmpty else {
            models = []
            errorMessage = providerForRequest == .codex ? "Connect Codex in Providers to load models." : "Add an API key in Providers to load models."
            return
        }
        isLoading = true
        task = Task { @MainActor in
            defer { if requestID == generation { isLoading = false; task = nil } }
            do {
                let available: [EditorProviderModel]
                if providerForRequest == .codex {
                    try await MobileCodexOAuth.refresh(force: false)
                    do {
                        available = try await loadCodexModels()
                    } catch EditorProviderModelCatalog.CatalogError.http(401) {
                        try await MobileCodexOAuth.refresh(force: true)
                        available = try await loadCodexModels()
                    }
                } else {
                    let request = try EditorProviderModelCatalog.apiRequest(baseURL: baseURL, apiKey: key)
                    available = try await EditorProviderModelCatalog.fetch(request)
                }
                try Task.checkCancellation()
                guard requestID == generation else {
                    return
                }
                models = available
                if !available.contains(where: { $0.id == modelID }) { modelID = "" }
                if selectedProvider == providerForRequest, let selected = available.first(where: { $0.id == selectedModelID }) {
                    selectedTitle = selected.title
                }
            } catch {
                guard !Task.isCancelled, requestID == generation else {
                    return
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadCodexModels() async throws -> [EditorProviderModel] {
        guard let credentials = MobileCodexCredentialStore.load() else {
            throw EditorProviderModelCatalog.CatalogError.http(401)
        }
        let request = try EditorProviderModelCatalog.codexRequest(accessToken: credentials.accessToken, accountID: credentials.accountID)
        return try await EditorProviderModelCatalog.fetch(request)
    }
}
#endif
