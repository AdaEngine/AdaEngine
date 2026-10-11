#if os(visionOS) && canImport(SloppyRuntime)
    import Foundation
    import Protocols
    import SloppyRuntime

    /// Adapts the existing portable runtime to the shared Studio agent transcript and tools.
    actor EditorVRRuntimeAgentService: EditorAgentServicing {
        private var turns: [String: Task<EditorAgentRunResult, Error>] = [:]

        func connect(
            _ request: EditorAgentRunRequest,
            onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
            onProjectFileChanged: @escaping @Sendable (String) async -> Void
        ) async throws -> EditorAgentSessionConfiguration {
            _ = try await credentials()
            return .init(agentName: "Ada", selectors: [])
        }

        func send(
            _ request: EditorAgentRunRequest,
            onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
            onProjectFileChanged: @escaping @Sendable (String) async -> Void
        ) async throws -> EditorAgentRunResult {
            let settings = try await credentials()
            let turn = Task {
                let runtime = SloppyRuntimeHost(additionalTools: try MobileEditorAgentToolBridge.definitions())
                if settings.provider == .codex {
                    guard let account = await MainActor.run(body: { MobileCodexCredentialStore.load() }) else {
                        throw EditorAgentServiceError.providerFailure("Sign in to Codex in Voice settings.")
                    }
                    try await runtime.configureCodex(
                        tokenProvider: { MobileCodexCredentialStore.load()?.accessToken ?? "" },
                        accountID: account.accountID,
                        model: settings.model,
                        refreshIfNeeded: { try await MobileCodexOAuth.refresh(force: false) },
                        refreshAfterInvalidToken: { try await MobileCodexOAuth.refresh(force: true) }
                    )
                } else {
                    try await runtime.configureOpenAI(apiKey: settings.apiKey, model: settings.model, apiURL: settings.apiURL)
                }
                let tools = await EditorMobileAgentToolService(projectURL: request.projectURL)
                let streamID = UUID().uuidString
                do {
                    let prompt = EditorAgentPromptContext.text(for: request)
                    let reply = try await runtime.send(
                        prompt: prompt,
                        sessionID: request.session.id,
                        workspaceURL: request.projectURL,
                        build: {
                            await MainActor.run {
                                let result = tools.build()
                                return SloppyBuildResult(ok: result.ok, summary: result.payload)
                            }
                        },
                        onText: { text in
                            guard !Task.isCancelled else {
                                return
                            }
                            await onEvent(
                                EditorAgentEvent(
                                    id: streamID,
                                    kind: .message,
                                    message: EditorAgentMessage(role: .assistant, segments: [.init(kind: .text, text: text)])
                                )
                            )
                        },
                        onActivity: { activity in
                            guard !Task.isCancelled else {
                                return
                            }
                            let title: String
                            switch activity {
                            case .thinking: title = "Thinking…"
                            case .toolStarted(let name): title = "Using \(name)…"
                            case let .toolFinished(name, ok): title = "\(name) \(ok ? "completed" : "failed")"
                            }
                            await onEvent(EditorAgentEvent(kind: .runStatus, title: title))
                        },
                        additionalToolHandler: { invocation in
                            guard !Task.isCancelled else {
                                return ToolInvocationResult(
                                    tool: invocation.tool,
                                    ok: false,
                                    error: ToolErrorPayload(code: "cancelled", message: "Agent stopped.", retryable: false)
                                )
                            }
                            let result = await MobileEditorAgentToolBridge.invoke(invocation, service: tools)
                            if result.ok, case .string(let path)? = invocation.arguments["path"] {
                                await onProjectFileChanged(path)
                            }
                            return result
                        },
                        persistedSessionID: request.session.upstreamSessionID ?? request.session.id
                    )
                    try Task.checkCancellation()
                    await tools.finish()
                    return EditorAgentRunResult(
                        upstreamSessionID: request.session.id,
                        assistantText: reply,
                        stopReason: "completed",
                        configuration: .init(agentName: "Ada", selectors: [])
                    )
                } catch {
                    await tools.finish()
                    throw error
                }
            }
            turns[request.session.id] = turn
            defer { turns.removeValue(forKey: request.session.id) }
            return try await turn.value
        }

        func setConfiguration(sessionID: String, selectorID: String, valueID: String) async throws -> EditorAgentSessionConfiguration {
            .init(agentName: "Ada", selectors: [])
        }
        func resolvePermission(requestID: String, optionID: String?) async {}
        func cancel(sessionID: String) async { turns[sessionID]?.cancel() }
        func shutdown() async { for turn in turns.values { turn.cancel() } }

        private func credentials() async throws -> MobileSloppyCredentials {
            guard let settings = await MainActor.run(body: { MobileSloppyCredentialStore.load() }),
                !settings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                settings.provider == .codex || !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw EditorAgentServiceError.providerFailure("Configure the provider in Voice settings before sending a prompt.") }
            return settings
        }
    }
#endif
