import ACP
import ACPModel
import Foundation

struct EditorAgentRunRequest: Sendable {
    var project: AdaProject
    var projectURL: URL
    var session: EditorAgentSession
    var mode: EditorAgentChatMode
    var prompt: String
    var attachments: [EditorAgentAttachment]
    var sceneContext: EditorAgentSceneContext?
    var skills: [EditorAgentSkill]
}

struct EditorAgentRunResult: Sendable {
    var upstreamSessionID: String?
    var assistantText: String
    var stopReason: String
}

protocol EditorAgentServicing: Sendable {
    func send(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult
    func cancel(sessionID: String) async
    func shutdown() async
}

enum EditorAgentServiceError: Error, LocalizedError, Sendable {
    case disabled
    case missingCommand
    case sessionUnavailable
    case pathOutsideProject(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Agent is disabled for this project."
        case .missingCommand:
            "ACP target command is not configured."
        case .sessionUnavailable:
            "ACP session is unavailable."
        case .pathOutsideProject(let path):
            "Agent path is outside the project: \(path)"
        }
    }
}

actor EditorACPAgentService: EditorAgentServicing {
    private struct ManagedSession {
        var client: Client
        var upstreamSessionID: SessionId
        var supportsLoadSession: Bool
        var agentName: String?
        var notificationTask: Task<Void, Never>
        var assistantText: String
    }

    private var sessions: [String: ManagedSession] = [:]

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
            stopReason: response.stopReason.rawValue
        )
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
        let supportsLoadSession = initialized.agentCapabilities.loadSession == true
        if let upstream = request.session.upstreamSessionID, supportsLoadSession {
            upstreamSessionID = try await client.loadSession(sessionId: SessionId(upstream), cwd: workingDirectory.path).sessionId
        } else {
            upstreamSessionID = try await client.newSession(workingDirectory: workingDirectory.path, timeout: 30).sessionId
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

        return ManagedSession(
            client: client,
            upstreamSessionID: upstreamSessionID,
            supportsLoadSession: supportsLoadSession,
            agentName: initialized.agentInfo?.title ?? initialized.agentInfo?.name,
            notificationTask: notificationTask,
            assistantText: ""
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

enum EditorAgentPromptContext {
    static func text(for request: EditorAgentRunRequest) -> String {
        var text = """
        [Mode: \(request.mode.rawValue)]
        """

        if let sceneContext = request.sceneContext {
            text += "\n\n\(sceneContextBlock(sceneContext))"
        }

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
}

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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
