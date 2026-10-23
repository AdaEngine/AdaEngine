import Foundation

/// Selecting Ada AI never launches or reconfigures a user's external ACP agent.
actor EditorCloudAgentRouter: EditorAgentServicing {
    static let command = "ada-cloud"
    static let entry = EditorInstalledAgent(
        id: "ada-cloud", name: "Ada AI", version: "Coder Next",
        target: .init(command: command), managedDirectory: nil, icon: nil)
    private let cloud = EditorCloudAgentService()
    private let fallback: any EditorAgentServicing
    private var cloudSessions: Set<String> = []
    init(fallback: any EditorAgentServicing) { self.fallback = fallback }
    private func selected(_ request: EditorAgentRunRequest) -> any EditorAgentServicing {
        let hosted = request.project.ai.agent.target.command == Self.command
        if hosted { cloudSessions.insert(request.session.id) } else { cloudSessions.remove(request.session.id) }
        return hosted ? cloud : fallback
    }
    func connect(
        _ request: EditorAgentRunRequest, onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentSessionConfiguration {
        try await selected(request).connect(request, onEvent: onEvent, onProjectFileChanged: onProjectFileChanged)
    }
    func send(
        _ request: EditorAgentRunRequest, onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult {
        try await selected(request).send(request, onEvent: onEvent, onProjectFileChanged: onProjectFileChanged)
    }
    func setConfiguration(sessionID: String, selectorID: String, valueID: String) async throws -> EditorAgentSessionConfiguration {
        let service: any EditorAgentServicing = cloudSessions.contains(sessionID) ? cloud : fallback
        return try await service.setConfiguration(sessionID: sessionID, selectorID: selectorID, valueID: valueID)
    }
    func resolvePermission(requestID: String, optionID: String?) async {
        await cloud.resolvePermission(requestID: requestID, optionID: optionID)
        await fallback.resolvePermission(requestID: requestID, optionID: optionID)
    }
    func cancel(sessionID: String) async {
        if cloudSessions.contains(sessionID) { await cloud.cancel(sessionID: sessionID) } else { await fallback.cancel(sessionID: sessionID) }
    }
    func shutdown() async {
        await cloud.shutdown()
        await fallback.shutdown()
        cloudSessions.removeAll()
    }
}
