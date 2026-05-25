@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

@Observable
@MainActor
final class EditorAgentViewModel {
    var connectionState: EditorAgentConnectionState = .disconnected
    var sessions: [EditorAgentSessionSummary] = []
    var activeSession: EditorAgentSession?
    var prompt: String = ""
    var mode: EditorAgentChatMode = .build
    var autocompleteSuggestions: [EditorAgentProjectFileSearch.Entry] = []
    var pendingAttachments: [EditorAgentAttachment] = []
    var sceneContext: EditorAgentSceneContext?
    var availableSkills: [EditorAgentSkill] = []
    var selectedSkillIDs: Set<String> = []
    var statusMessage: String?
    var isSending = false

    @ObservationIgnored
    private let project: EditorProjectReference?
    @ObservationIgnored
    private let service: any EditorAgentServicing
    @ObservationIgnored
    private var store: EditorAgentSessionStore?
    @ObservationIgnored
    private var projectConfig: AdaProject?
    @ObservationIgnored
    private let fileManager: FileManager
    @ObservationIgnored
    private var onProjectFileChanged: (String) -> Void

    init(
        project: EditorProjectReference?,
        fileManager: FileManager = .default,
        service: any EditorAgentServicing = EditorACPAgentService(),
        onProjectFileChanged: @escaping (String) -> Void = { _ in }
    ) {
        self.project = project
        self.fileManager = fileManager
        self.service = service
        self.onProjectFileChanged = onProjectFileChanged
        configureForProject()
    }

    func setProjectFileChangedHandler(_ handler: @escaping (String) -> Void) {
        onProjectFileChanged = handler
    }

    func setSceneContext(_ context: EditorAgentSceneContext?) {
        sceneContext = context
    }

    var promptBinding: Binding<String> {
        Binding(
            get: { self.prompt },
            set: { newValue in
                self.prompt = newValue
                self.updateAutocomplete()
            }
        )
    }

    var canSend: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var selectedSkills: [EditorAgentSkill] {
        availableSkills.filter { selectedSkillIDs.contains($0.id) }
    }

    var projectURL: URL? {
        project.map { URL(fileURLWithPath: $0.path, isDirectory: true) }
    }

    func configureForProject() {
        guard let projectURL else {
            statusMessage = "No project is open."
            return
        }

        store = EditorAgentSessionStore(projectURL: projectURL)
        do {
            projectConfig = try ProjectSystem.loadProject(at: projectURL, fileManager: fileManager)
        } catch {
            projectConfig = ProjectSystem.defaultProject(projectName: project?.name ?? "Project")
            statusMessage = "Using default agent configuration."
        }

        if let projectConfig {
            availableSkills = EditorAgentSkillStore.discoverSkills(
                projectURL: projectURL,
                directories: projectConfig.ai.agent.skillsDirectories,
                fileManager: fileManager
            )
            connectionState = projectConfig.ai.agent.enabled ? .disconnected : .failed("Agent is disabled in project metadata.")
        }

        Task {
            await loadSessions()
        }
    }

    func loadSessions() async {
        guard let store else {
            return
        }

        do {
            sessions = try await store.listSessions()
            if let activeID = try await store.activeSessionID(), let session = try? await store.loadSession(id: activeID) {
                activeSession = session
                selectedSkillIDs = Set(session.selectedSkillIDs)
            } else if let first = sessions.first, let session = try? await store.loadSession(id: first.id) {
                activeSession = session
                selectedSkillIDs = Set(session.selectedSkillIDs)
                try await store.setActiveSession(id: first.id)
            } else {
                try await createSession()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func createSession() async throws {
        guard let store else {
            return
        }
        let session = try await store.createSession()
        activeSession = session
        sessions = try await store.listSessions()
        selectedSkillIDs = []
        prompt = ""
        pendingAttachments = []
    }

    func selectSession(_ summary: EditorAgentSessionSummary) {
        guard let store else {
            return
        }
        Task {
            do {
                activeSession = try await store.loadSession(id: summary.id)
                selectedSkillIDs = Set(activeSession?.selectedSkillIDs ?? [])
                try await store.setActiveSession(id: summary.id)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func deleteActiveSession() {
        guard let store, let activeSession else {
            return
        }
        Task {
            do {
                await service.cancel(sessionID: activeSession.id)
                try await store.deleteSession(id: activeSession.id)
                sessions = try await store.listSessions()
                if let next = sessions.first {
                    self.activeSession = try await store.loadSession(id: next.id)
                    try await store.setActiveSession(id: next.id)
                } else {
                    try await createSession()
                }
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func sendPrompt() {
        guard canSend else {
            return
        }
        Task {
            await sendPromptAsync()
        }
    }

    func interrupt() {
        guard let activeSession else {
            return
        }
        Task {
            await service.cancel(sessionID: activeSession.id)
            appendEvent(EditorAgentEvent(kind: .runStatus, title: "Interrupted", details: nil))
            await saveActiveSession()
            isSending = false
            connectionState = .disconnected
        }
    }

    func toggleSkill(_ skill: EditorAgentSkill) {
        if selectedSkillIDs.contains(skill.id) {
            selectedSkillIDs.remove(skill.id)
        } else {
            selectedSkillIDs.insert(skill.id)
        }
        activeSession?.selectedSkillIDs = Array(selectedSkillIDs).sorted()
        Task {
            await saveActiveSession()
        }
    }

    func attachFile(at url: URL) {
        guard let projectURL else {
            return
        }
        pendingAttachments.append(EditorAgentAttachmentContext.attachment(forFileAt: url, projectURL: projectURL, fileManager: fileManager))
    }

    func insertAutocomplete(_ entry: EditorAgentProjectFileSearch.Entry) {
        guard let token = EditorAgentPathTokens.tokenBeforeCursor(in: prompt) else {
            return
        }
        prompt.replaceSubrange(token.range, with: "@\(EditorAgentPathTokens.escapedTokenValue(entry.path))")
        autocompleteSuggestions = []
    }

    func sendPromptAsync() async {
        guard var session = activeSession,
              let projectConfig,
              let projectURL else {
            statusMessage = "No active agent session."
            return
        }

        let preparedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let invokedSkills = skillsInvokedByPrompt(preparedPrompt)
        let requestSkills = selectedSkills + invokedSkills.filter { skill in !selectedSkillIDs.contains(skill.id) }
        let requestPrompt = promptRemovingSkillSlashCommand(preparedPrompt, invokedSkills: invokedSkills)

        let tokenAttachments = EditorAgentPathTokens.attachmentPaths(in: preparedPrompt).compactMap { path -> EditorAgentAttachment? in
            let url = projectURL.appendingPathComponent(path).standardizedFileURL
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }
            return EditorAgentAttachmentContext.attachment(forFileAt: url, projectURL: projectURL, fileManager: fileManager)
        }
        let attachmentsToSend = uniqueAttachments(pendingAttachments + tokenAttachments)

        let userSegments = [
            EditorAgentMessageSegment(kind: .text, text: preparedPrompt)
        ] + attachmentsToSend.map {
            EditorAgentMessageSegment(kind: .attachment, attachment: $0)
        } + requestSkills.map {
            EditorAgentMessageSegment(kind: .skill, skill: $0)
        }

        session.events.append(EditorAgentEvent(
            kind: .message,
            message: EditorAgentMessage(role: .user, segments: userSegments)
        ))
        session.attachments.append(contentsOf: attachmentsToSend)
        session.selectedSkillIDs = Array(selectedSkillIDs).sorted()
        session.updatedAt = Date()
        activeSession = session
        prompt = ""
        autocompleteSuggestions = []
        let attachments = attachmentsToSend
        pendingAttachments = []
        isSending = true
        connectionState = .connecting
        await saveActiveSession()

        do {
            connectionState = .running
            let result = try await service.send(
                EditorAgentRunRequest(
                    project: projectConfig,
                    projectURL: projectURL,
                    session: session,
                    mode: mode,
                    prompt: requestPrompt,
                    attachments: attachments,
                    sceneContext: sceneContext,
                    skills: requestSkills
                ),
                onEvent: { [weak self] event in
                    await MainActor.run {
                        self?.appendEvent(event)
                    }
                },
                onProjectFileChanged: { [weak self] relativePath in
                    await MainActor.run {
                        self?.onProjectFileChanged(relativePath)
                    }
                }
            )
            activeSession?.upstreamSessionID = result.upstreamSessionID
            appendEvent(EditorAgentEvent(kind: .runStatus, title: "Done", details: result.stopReason))
            connectionState = .ready(nil)
        } catch {
            appendEvent(EditorAgentEvent(kind: .error, title: "Agent failed", details: error.localizedDescription, isSuccessful: false))
            connectionState = .failed(error.localizedDescription)
        }

        isSending = false
        await saveActiveSession()
    }

    private func appendEvent(_ event: EditorAgentEvent) {
        guard var session = activeSession else {
            return
        }

        if event.kind == .message,
           event.message?.role == .assistant,
           event.message?.segments.first?.kind == .text,
           let lastIndex = session.events.lastIndex(where: { $0.kind == .message && $0.message?.role == .assistant && $0.message?.segments.first?.kind == .text }) {
            session.events[lastIndex] = event
        } else {
            session.events.append(event)
        }

        session.updatedAt = Date()
        if let userText = session.events.compactMap(\.message).first(where: { $0.role == .user })?.segments.first?.text {
            session.title = String(userText.prefix(48)).nilIfEmpty ?? session.title
        }
        activeSession = session
    }

    private func saveActiveSession() async {
        guard let store, let activeSession else {
            return
        }
        do {
            try await store.saveSession(activeSession, makeActive: true)
            sessions = try await store.listSessions()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func updateAutocomplete() {
        guard let projectURL, let token = EditorAgentPathTokens.tokenBeforeCursor(in: prompt) else {
            autocompleteSuggestions = []
            return
        }
        autocompleteSuggestions = EditorAgentProjectFileSearch.search(
            projectURL: projectURL,
            query: token.path,
            limit: 8,
            fileManager: fileManager
        )
    }

    private func skillsInvokedByPrompt(_ prompt: String) -> [EditorAgentSkill] {
        guard prompt.hasPrefix("/") else {
            return []
        }
        let command = prompt.split(separator: " ", maxSplits: 1).first.map { String($0.dropFirst()) } ?? ""
        return availableSkills.filter { $0.userInvocable && ($0.id == command || $0.name == command) }
    }

    private func promptRemovingSkillSlashCommand(_ prompt: String, invokedSkills: [EditorAgentSkill]) -> String {
        guard !invokedSkills.isEmpty, let firstSpace = prompt.firstIndex(of: " ") else {
            return prompt
        }
        return String(prompt[prompt.index(after: firstSpace)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniqueAttachments(_ attachments: [EditorAgentAttachment]) -> [EditorAgentAttachment] {
        var seen = Set<String>()
        var result: [EditorAgentAttachment] = []
        for attachment in attachments where !seen.contains(attachment.absolutePath) {
            seen.insert(attachment.absolutePath)
            result.append(attachment)
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
