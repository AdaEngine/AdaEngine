#if canImport(ACP) && canImport(ACPModel)
import ACP
import ACPModel
#endif
import Foundation

struct EditorAgentRunRequest: Sendable {
    var project: AdaProject
    var projectURL: URL
    var session: EditorAgentSession
    var mode: EditorAgentChatMode
    var prompt: String
    var attachments: [EditorAgentAttachment]
    var sceneContext: EditorAgentSceneContext?
    var codeSelection: EditorAgentCodeSelectionContext?
    var skills: [EditorAgentSkill]
}

struct EditorAgentRunResult: Sendable {
    var upstreamSessionID: String?
    var assistantText: String
    var stopReason: String
    var configuration: EditorAgentSessionConfiguration
}

protocol EditorAgentServicing: Sendable {
    func connect(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentSessionConfiguration
    func send(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult
    func setConfiguration(sessionID: String, selectorID: String, valueID: String) async throws -> EditorAgentSessionConfiguration
    func cancel(sessionID: String) async
    func shutdown() async
}

enum EditorAgentServiceError: Error, LocalizedError, Sendable {
    case disabled
    case missingCommand
    case unsupportedPlatform
    case sessionUnavailable
    case pathOutsideProject(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Agent is disabled for this project."
        case .missingCommand:
            "ACP target command is not configured."
        case .unsupportedPlatform:
            "ACP agent integration is unavailable on this platform."
        case .sessionUnavailable:
            "ACP session is unavailable."
        case .pathOutsideProject(let path):
            "Agent path is outside the project: \(path)"
        }
    }
}

#if canImport(ACP) && canImport(ACPModel)
actor EditorACPAgentService: EditorAgentServicing {
    private struct ManagedSession {
        var client: Client
        var upstreamSessionID: SessionId
        var supportsLoadSession: Bool
        var agentName: String?
        var notificationTask: Task<Void, Never>
        var assistantText: String
        var configuration: EditorAgentSessionConfiguration
    }

    private var sessions: [String: ManagedSession] = [:]

    func connect(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentSessionConfiguration {
        let managed = try await prepareSession(
            request: request,
            onEvent: onEvent,
            onProjectFileChanged: onProjectFileChanged
        )
        return managed.configuration
    }

    func send(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult {
        guard request.project.ai.agent.enabled else {
            throw EditorAgentServiceError.disabled
        }

        var managed = try await prepareSession(
            request: request,
            onEvent: onEvent,
            onProjectFileChanged: onProjectFileChanged
        )
        managed.assistantText = ""
        sessions[request.session.id] = managed

        let response = try await managed.client.sendPrompt(
            sessionId: managed.upstreamSessionID,
            content: try promptContent(for: request)
        )

        managed = sessions[request.session.id] ?? managed
        managed.assistantText = managed.assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[request.session.id] = managed

        return EditorAgentRunResult(
            upstreamSessionID: managed.upstreamSessionID.value,
            assistantText: managed.assistantText,
            stopReason: response.stopReason.rawValue,
            configuration: managed.configuration
        )
    }

    func setConfiguration(sessionID: String, selectorID: String, valueID: String) async throws -> EditorAgentSessionConfiguration {
        guard var managed = sessions[sessionID],
              let selectorIndex = managed.configuration.selectors.firstIndex(where: { $0.id == selectorID }) else {
            throw EditorAgentServiceError.sessionUnavailable
        }

        let selector = managed.configuration.selectors[selectorIndex]
        if selector.usesLegacyMethod {
            switch selector.category {
            case .mode:
                _ = try await managed.client.setMode(sessionId: managed.upstreamSessionID, modeId: valueID)
            case .model:
                _ = try await managed.client.setModel(sessionId: managed.upstreamSessionID, modelId: valueID)
            case .reasoning, .other:
                throw EditorAgentServiceError.sessionUnavailable
            }
            managed.configuration.selectors[selectorIndex].currentValueID = valueID
        } else {
            let response = try await managed.client.setConfigOption(
                sessionId: managed.upstreamSessionID,
                configId: SessionConfigId(selectorID),
                value: SessionConfigValueId(valueID)
            )
            managed.configuration = Self.configuration(
                agentName: managed.agentName,
                modes: nil,
                models: nil,
                configOptions: response.configOptions
            )
        }
        sessions[sessionID] = managed
        return managed.configuration
    }

    func cancel(sessionID: String) async {
        guard let managed = sessions[sessionID] else {
            return
        }
        try? await managed.client.cancelSession(sessionId: managed.upstreamSessionID)
    }

    func shutdown() async {
        for session in sessions.values {
            session.notificationTask.cancel()
            await session.client.terminate()
        }
        sessions.removeAll()
    }

    private func prepareSession(
        request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> ManagedSession {
        if let existing = sessions[request.session.id] {
            return existing
        }

        let agentConfig = request.project.ai.agent
        guard let command = agentConfig.target.command?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
            throw EditorAgentServiceError.missingCommand
        }

        let client = Client()
        let projectURL = request.projectURL.standardizedFileURL
        let delegate = EditorACPClientDelegate(
            projectURL: projectURL,
            permissionMode: agentConfig.permissionMode,
            onEvent: onEvent,
            onProjectFileChanged: onProjectFileChanged
        )
        await client.setDelegate(delegate)

        let workingDirectory = effectiveWorkingDirectory(projectURL: projectURL, target: agentConfig.target)
        try await client.launch(
            agentPath: command,
            arguments: agentConfig.target.arguments,
            workingDirectory: workingDirectory.path,
            environment: agentConfig.target.environment
        )
        let initialized = try await client.initialize(
            capabilities: ClientCapabilities(
                fs: FileSystemCapabilities(readTextFile: true, writeTextFile: true),
                terminal: true
            ),
            clientInfo: ClientInfo(name: "AdaEditor", title: "Ada Editor", version: "1.0.0"),
            timeout: 30
        )

        let upstreamSessionID: SessionId
        let modes: ModesInfo?
        let models: ModelsInfo?
        let configOptions: [SessionConfigOption]?
        let supportsLoadSession = initialized.agentCapabilities.loadSession == true
        if let upstream = request.session.upstreamSessionID, supportsLoadSession {
            let response = try await client.loadSession(sessionId: SessionId(upstream), cwd: workingDirectory.path)
            upstreamSessionID = response.sessionId
            modes = response.modes
            models = response.models
            configOptions = response.configOptions
        } else {
            let response = try await client.newSession(
                workingDirectory: workingDirectory.path,
                mcpServers: mcpServers(for: request.project),
                timeout: 30
            )
            upstreamSessionID = response.sessionId
            modes = response.modes
            models = response.models
            configOptions = response.configOptions
        }

        let localSessionID = request.session.id
        let notificationTask = Task { [weak self] in
            for await notification in await client.notifications {
                await self?.handleNotification(
                    localSessionID: localSessionID,
                    upstreamSessionID: upstreamSessionID,
                    notification: notification,
                    onEvent: onEvent
                )
            }
        }

        let agentName = initialized.agentInfo?.title ?? initialized.agentInfo?.name
        return ManagedSession(
            client: client,
            upstreamSessionID: upstreamSessionID,
            supportsLoadSession: supportsLoadSession,
            agentName: agentName,
            notificationTask: notificationTask,
            assistantText: "",
            configuration: Self.configuration(
                agentName: agentName,
                modes: modes,
                models: models,
                configOptions: configOptions
            )
        )
    }

    private func mcpServers(for project: AdaProject) -> [MCPServerConfig] {
        guard project.ai.mcp.enabled else {
            return []
        }
        return [
            .http(HTTPServerConfig(name: "AdaEditor Runtime", url: "http://127.0.0.1:2510/mcp"))
        ]
    }

    private static func configuration(
        agentName: String?,
        modes: ModesInfo?,
        models: ModelsInfo?,
        configOptions: [SessionConfigOption]?
    ) -> EditorAgentSessionConfiguration {
        var selectors = (configOptions ?? []).compactMap(configurationSelector)
        if selectors.contains(where: { $0.category == .mode }) == false, let modes {
            selectors.append(EditorAgentConfigurationSelector(
                id: "mode",
                name: "Mode",
                category: .mode,
                currentValueID: modes.currentModeId,
                choices: modes.availableModes.map { .init(id: $0.id, name: $0.name, description: $0.description) },
                usesLegacyMethod: true
            ))
        }
        if selectors.contains(where: { $0.category == .model }) == false, let models {
            selectors.append(EditorAgentConfigurationSelector(
                id: "model",
                name: "Model",
                category: .model,
                currentValueID: models.currentModelId,
                choices: models.availableModels.map { .init(id: $0.modelId, name: $0.name, description: $0.description) },
                usesLegacyMethod: true
            ))
        }
        return EditorAgentSessionConfiguration(agentName: agentName, selectors: selectors)
    }

    private static func configurationSelector(_ option: SessionConfigOption) -> EditorAgentConfigurationSelector? {
        guard case .select(let select) = option.kind else {
            return nil
        }
        let choices: [EditorAgentConfigurationChoice] = switch select.options {
        case .ungrouped(let options):
            options.map { .init(id: $0.value.value, name: $0.name, description: $0.description) }
        case .grouped(let groups):
            groups.flatMap { group in
                group.options.map { .init(id: $0.value.value, name: $0.name, description: $0.description) }
            }
        }
        let normalizedCategory = (option.category ?? option.id.value).lowercased()
        let category: EditorAgentConfigurationCategory = switch normalizedCategory {
        case "mode": .mode
        case "model": .model
        case "thought_level", "reasoning", "reasoning_effort": .reasoning
        default: .other
        }
        return EditorAgentConfigurationSelector(
            id: option.id.value,
            name: option.name,
            category: category,
            currentValueID: select.currentValue.value,
            choices: choices,
            usesLegacyMethod: false
        )
    }

    private func effectiveWorkingDirectory(projectURL: URL, target: AdaProjectAgentTarget) -> URL {
        guard let cwd = target.cwd?.trimmingCharacters(in: .whitespacesAndNewlines), !cwd.isEmpty else {
            return projectURL
        }
        return projectURL.appendingPathComponent(cwd, isDirectory: true).standardizedFileURL
    }

    private func promptContent(for request: EditorAgentRunRequest) throws -> [ContentBlock] {
        let text = EditorAgentPromptContext.text(for: request)
        var content: [ContentBlock] = [.text(TextContent(text: text))]
        for attachment in request.attachments where attachment.mimeType.hasPrefix("image/") {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: attachment.absolutePath)) else {
                continue
            }
            content.append(.image(ImageContent(
                data: data.base64EncodedString(),
                mimeType: attachment.mimeType,
                uri: URL(fileURLWithPath: attachment.absolutePath).absoluteString
            )))
        }
        return content
    }

    private func handleNotification(
        localSessionID: String,
        upstreamSessionID: SessionId,
        notification: JSONRPCNotification,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void
    ) async {
        guard notification.method == "session/update",
              let payload = decode(notification: notification, as: SessionUpdateNotification.self),
              payload.sessionId == upstreamSessionID,
              var managed = sessions[localSessionID] else {
            return
        }

        switch payload.update {
        case .agentMessageChunk(let block):
            let text = flatten(content: block)
            guard !text.isEmpty else { return }
            managed.assistantText += text
            sessions[localSessionID] = managed
            await onEvent(EditorAgentEvent(
                kind: .message,
                message: EditorAgentMessage(
                    role: .assistant,
                    segments: [.init(kind: .text, text: managed.assistantText)]
                )
            ))
        case .agentThoughtChunk(let block):
            let text = flatten(content: block)
            guard !text.isEmpty else { return }
            await onEvent(EditorAgentEvent(
                kind: .message,
                message: EditorAgentMessage(role: .assistant, segments: [.init(kind: .thinking, text: text)])
            ))
        case .plan(let plan):
            let text = plan.entries.map { "[\($0.status)] \($0.content)" }.joined(separator: "\n")
            guard !text.isEmpty else { return }
            await onEvent(EditorAgentEvent(kind: .runStatus, title: "Plan", details: text))
        case .toolCall(let toolCall):
            let details = toolCall.content.compactMap(\.displayText).joined(separator: "\n")
            await onEvent(EditorAgentEvent(
                kind: .toolCall,
                title: toolCall.title ?? toolCall.kind?.rawValue ?? "Tool call",
                details: details.nilIfEmpty
            ))
            if toolCall.status == .completed || toolCall.status == .failed {
                await onEvent(EditorAgentEvent(
                    kind: .toolResult,
                    title: toolCall.title ?? toolCall.kind?.rawValue ?? "Tool result",
                    details: details.nilIfEmpty,
                    isSuccessful: toolCall.status == .completed
                ))
            }
        case .toolCallUpdate(let details):
            await onEvent(EditorAgentEvent(
                kind: .toolResult,
                title: "Tool \(details.toolCallId)",
                details: details.content?.compactMap(\.displayText).joined(separator: "\n").nilIfEmpty,
                isSuccessful: details.status.map { $0 == .completed }
            ))
        case .sessionInfoUpdate(let info):
            if let title = info.title {
                await onEvent(EditorAgentEvent(kind: .runStatus, title: "Session updated", details: title))
            }
        default:
            break
        }
    }

    private func decode<T: Decodable>(notification: JSONRPCNotification, as type: T.Type) -> T? {
        guard let params = notification.params,
              let data = try? JSONEncoder().encode(params) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func flatten(content: ContentBlock) -> String {
        switch content {
        case .text(let text):
            return text.text
        case .resource(let resource):
            return resource.resource.text ?? ""
        case .resourceLink(let link):
            return link.uri
        case .image, .audio:
            return ""
        }
    }
}
#else
actor EditorACPAgentService: EditorAgentServicing {
    func connect(
        _: EditorAgentRunRequest,
        onEvent _: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged _: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentSessionConfiguration {
        throw EditorAgentServiceError.unsupportedPlatform
    }

    func send(
        _: EditorAgentRunRequest,
        onEvent _: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged _: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult {
        throw EditorAgentServiceError.unsupportedPlatform
    }

    func setConfiguration(sessionID _: String, selectorID _: String, valueID _: String) async throws -> EditorAgentSessionConfiguration {
        throw EditorAgentServiceError.unsupportedPlatform
    }

    func cancel(sessionID _: String) async {}

    func shutdown() async {}
}
#endif

enum EditorAgentPromptContext {
    static func text(for request: EditorAgentRunRequest) -> String {
        var text = """
        [Mode: \(request.mode.rawValue)]
        """

        if let sceneContext = request.sceneContext {
            text += "\n\n\(sceneContextBlock(sceneContext))"
        }

        if let codeSelection = request.codeSelection {
            text += "\n\n\(codeSelectionBlock(codeSelection))"
        }

        text += "\n\n\(projectCapabilitiesBlock(request.project))"

        text += "\n\n\(request.prompt)"

        for skill in request.skills where skill.userInvocable {
            text += "\n\n[Skill: \(skill.name)]\n\(skill.instructions)"
        }
        for attachment in request.attachments {
            text += "\n\n\(EditorAgentAttachmentContext.fileReferenceBlock(attachment: attachment))"
        }

        return text
    }

    private static func sceneContextBlock(_ context: EditorAgentSceneContext) -> String {
        var lines = [
            "[Scene Context]",
            "Scene: \(context.sceneTitle)",
            "Scene path: \(context.sceneRelativePath)",
            "Selected entity: \(context.selectedEntityName) (\(context.selectedEntityID))"
        ]

        if let parentID = context.parentID {
            lines.append("Parent entity id: \(parentID)")
        }

        if !context.componentNames.isEmpty {
            lines.append("Components: \(context.componentNames.joined(separator: ", "))")
        }

        lines.append("Selected entity YAML:")
        lines.append(context.entityYAML)
        return lines.joined(separator: "\n")
    }

    private static func codeSelectionBlock(_ context: EditorAgentCodeSelectionContext) -> String {
        """
        [Selected Code]
        File: \(context.documentRelativePath)
        Range: \(context.lineDescription)
        Language: \(context.language)
        ```\(context.language)
        \(context.text)
        ```
        """
    }

    private static func projectCapabilitiesBlock(_ project: AdaProject) -> String {
        let sources = project.paths.sources ?? "Sources"
        let assets = project.paths.assets ?? "Assets"
        return """
        [AdaEditor Project Capabilities]
        - Scene documents: *.ascn/*.scene/*.scn (YAML); edit them through project files and preserve schemaVersion.
        - Swift and Ada Script code: \(sources) (Swift: *.swift, Ada Script: *.ada).
        - Shaders: *.glsl/*.vert/*.frag/*.shader/*.metal under the project, commonly in \(assets).
        - Assets and project files: \(assets) and the project tree; project metadata is .ada/project.json.
        - The AdaEditor Runtime MCP server exposes live worlds, entities, components, assets, render captures, UI, traces, and profiler data.
        - After edits, run the narrowest relevant build or test and report failures precisely.
        """
    }
}

#if canImport(ACP) && canImport(ACPModel)
private actor EditorACPClientDelegate: ClientDelegate {
    private let terminalDelegate = TerminalDelegate()
    private let projectURL: URL
    private let permissionMode: AdaProjectAgentPermissionMode
    private let onEvent: @Sendable (EditorAgentEvent) async -> Void
    private let onProjectFileChanged: @Sendable (String) async -> Void

    init(
        projectURL: URL,
        permissionMode: AdaProjectAgentPermissionMode,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) {
        self.projectURL = projectURL.standardizedFileURL
        self.permissionMode = permissionMode
        self.onEvent = onEvent
        self.onProjectFileChanged = onProjectFileChanged
    }

    func handleFileReadRequest(_ path: String, sessionId _: String, line: Int?, limit: Int?) async throws -> ReadTextFileResponse {
        let url = try resolvedProjectURL(path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        let filtered: String
        if let line, let limit {
            let start = max(0, line - 1)
            let end = min(lines.count, start + limit)
            filtered = lines[start..<end].joined(separator: "\n")
        } else if let line {
            let start = max(0, line - 1)
            filtered = lines[start...].joined(separator: "\n")
        } else {
            filtered = content
        }
        return ReadTextFileResponse(content: filtered, totalLines: lines.count)
    }

    func handleFileWriteRequest(_ path: String, content: String, sessionId _: String) async throws -> WriteTextFileResponse {
        let url = try resolvedProjectURL(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        await onProjectFileChanged(relativePath(for: url))
        return WriteTextFileResponse()
    }

    func handleTerminalCreate(command: String, sessionId: String, args: [String]?, cwd: String?, env: [EnvVariable]?, outputByteLimit: Int?) async throws -> CreateTerminalResponse {
        if let cwd {
            _ = try resolvedProjectURL(cwd)
        }
        return try await terminalDelegate.handleTerminalCreate(
            command: command,
            sessionId: sessionId,
            args: args,
            cwd: cwd ?? projectURL.path,
            env: env,
            outputByteLimit: outputByteLimit
        )
    }

    func handleTerminalOutput(terminalId: TerminalId, sessionId: String) async throws -> TerminalOutputResponse {
        try await terminalDelegate.handleTerminalOutput(terminalId: terminalId, sessionId: sessionId)
    }

    func handleTerminalWaitForExit(terminalId: TerminalId, sessionId: String) async throws -> WaitForExitResponse {
        try await terminalDelegate.handleTerminalWaitForExit(terminalId: terminalId, sessionId: sessionId)
    }

    func handleTerminalKill(terminalId: TerminalId, sessionId: String) async throws -> KillTerminalResponse {
        try await terminalDelegate.handleTerminalKill(terminalId: terminalId, sessionId: sessionId)
    }

    func handleTerminalRelease(terminalId: TerminalId, sessionId: String) async throws -> ReleaseTerminalResponse {
        try await terminalDelegate.handleTerminalRelease(terminalId: terminalId, sessionId: sessionId)
    }

    func handlePermissionRequest(request: RequestPermissionRequest) async throws -> RequestPermissionResponse {
        let summary = request.message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? request.toolCall.map { "Permission requested for tool call \($0.toolCallId)" }
            ?? "Permission requested"
        await onEvent(EditorAgentEvent(kind: .permission, title: "Permission", details: summary))

        switch permissionMode {
        case .allowOnce:
            if let optionID = request.options?.first(where: { $0.optionId == PermissionDecision.allowOnce.rawValue })?.optionId {
                await onEvent(EditorAgentEvent(kind: .permission, title: "Allowed once", details: summary, isSuccessful: true))
                return RequestPermissionResponse(outcome: PermissionOutcome(optionId: optionID))
            }
            fallthrough
        case .deny:
            await onEvent(EditorAgentEvent(kind: .permission, title: "Denied", details: summary, isSuccessful: false))
            return RequestPermissionResponse(outcome: PermissionOutcome(cancelled: true))
        }
    }

    private func resolvedProjectURL(_ path: String) throws -> URL {
        let candidate: URL
        if path.hasPrefix("/") {
            candidate = URL(fileURLWithPath: path).standardizedFileURL
        } else {
            candidate = projectURL.appendingPathComponent(path).standardizedFileURL
        }
        guard candidate.path == projectURL.path || candidate.path.hasPrefix(projectURL.path + "/") else {
            throw EditorAgentServiceError.pathOutsideProject(path)
        }
        return candidate
    }

    private func relativePath(for url: URL) -> String {
        let standardized = url.standardizedFileURL
        guard standardized.path.hasPrefix(projectURL.path + "/") else {
            return standardized.path
        }
        return String(standardized.path.dropFirst(projectURL.path.count + 1))
    }
}
#endif

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
