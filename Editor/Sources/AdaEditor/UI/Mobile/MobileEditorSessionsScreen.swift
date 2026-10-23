#if os(iOS) || os(Android)
@_spi(AdaEngine) import AdaEngine
import Foundation
import Protocols
import SloppyRuntime

struct MobileEditorSessionSummary: Identifiable, Sendable {
    let id: String
    let title: String
    let updatedAt: Date
    let messageCount: Int
    let preview: String
}

actor MobileEditorSessionStore {
    let workspaceURL: URL

    init(workspaceURL: URL) { self.workspaceURL = workspaceURL }

    private var agentsURL: URL { workspaceURL.appendingPathComponent(".ada/workspace/agents", isDirectory: true) }

    func list() async throws -> [MobileEditorSessionSummary] {
        let native = EditorAgentSessionStore(projectURL: workspaceURL)
        var result: [MobileEditorSessionSummary] = []
        for summary in try await native.listSessions() where Self.cloudID(summary.id) {
            let session = try await native.loadSession(id: summary.id)
            let messages = session.events.compactMap(\.message)
            result.append(.init(id: summary.id, title: summary.title, updatedAt: summary.updatedAt,
                                messageCount: messages.count, preview: String((messages.last?.segments.first?.text ?? "").prefix(200))))
        }
        if FileManager.default.fileExists(atPath: agentsURL.appendingPathComponent("mobile").path) {
            let store = AgentSessionFileStore(agentsRootURL: agentsURL)
            for summary in try store.listSessions(agentID: "mobile") {
                let detail = try store.loadSession(agentID: "mobile", sessionID: summary.id)
                let messages = await MobileSloppyChatAdapter.events(from: detail.events).compactMap(\.message)
                let title = messages.first(where: { $0.role == .user })?.segments.first?.text ?? summary.title
                result.append(.init(id: summary.id, title: String(title.prefix(80)), updatedAt: summary.updatedAt,
                             messageCount: messages.count, preview: String((messages.last?.segments.first?.text ?? "").prefix(200))))
            }
        }
        return result.sorted { $0.updatedAt > $1.updatedAt }
    }
    private static func cloudID(_ id: String) -> Bool {
        id.hasPrefix("cloud-") && id.range(of: "^[a-zA-Z0-9_-]{1,100}$", options: .regularExpression) != nil
    }

    func messages(id: String) throws -> [SloppyChatMessage] {
        let detail = try AgentSessionFileStore(agentsRootURL: agentsURL).loadSession(agentID: "mobile", sessionID: id)
        return detail.events.compactMap { event in
            guard let message = event.message else { return nil }
            let role: SloppyChatMessage.Role
            switch message.role {
            case .user: role = .user
            case .assistant: role = .assistant
            case .system: return nil
            }
            let rawText = message.segments.compactMap(\.text).joined(separator: "\n")
            guard let text = role == .user ? MobileEditorAgentContext.visibleText(rawText)
                : rawText.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return SloppyChatMessage(id: event.id, role: role, text: text, createdAt: event.createdAt)
        }
    }

    func events(id: String? = nil) async throws -> [EditorAgentEvent] {
        let sessionID: String
        if let id { sessionID = id }
        else if let first = try await list().first { sessionID = first.id }
        else { return [] }
        if Self.cloudID(sessionID) { return try await EditorAgentSessionStore(projectURL: workspaceURL).loadSession(id: sessionID).events }
        let detail = try AgentSessionFileStore(agentsRootURL: agentsURL).loadSession(agentID: "mobile", sessionID: sessionID)
        return await MobileSloppyChatAdapter.events(from: detail.events)
    }
}

struct MobileEditorSessionsScreen: View {
    @Environment(\.theme) private var theme
    @State private var sessions: [MobileEditorSessionSummary] = []
    @State private var status = "Loading sessions…"
    @State private var loadTask: Task<Void, Never>?
    let workspaceURL: URL
    var cloud = false
    let open: (String) -> Void

    var body: some View {
        MobileEditorPageScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !status.isEmpty {
                    Text(status).font(MobileEditorFont.font(size: 14)).foregroundColor(theme.editorColors.muted)
                }
                ForEach(sessions) { session in
                    Button { open(session.id) } label: {
                        MobileEditorCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(session.title).font(MobileEditorFont.font(size: 17)).foregroundColor(theme.editorColors.text)
                                Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened) + " · \(session.messageCount) messages")
                                    .font(MobileEditorFont.font(size: 11)).foregroundColor(theme.editorColors.muted)
                                Text(session.preview).font(MobileEditorFont.font(size: 13)).foregroundColor(theme.editorColors.muted).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(17)
                        }
                    }
                    .accessibilityIdentifier("AdaEditor.Mobile.Session.\(session.id)")
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .background(theme.editorColors.background)
        .onAppear {
            loadTask = Task { @MainActor in
                do {
                    let loaded = try await MobileEditorSessionStore(workspaceURL: workspaceURL).list()
                    try Task.checkCancellation()
                    sessions = loaded.filter { $0.id.hasPrefix("cloud-") == cloud }
                    status = sessions.isEmpty ? "No sessions yet. Your conversations will appear here after the first request." : ""
                } catch { if !Task.isCancelled { status = error.localizedDescription } }
            }
        }
        .onDisappear { loadTask?.cancel() }
    }
}

struct MobileEditorSessionDetailScreen: View {
    @Environment(\.theme) private var theme
    @State private var interfaces = EditorMobileA2UIStore(shouldPersist: false)
    @State private var events: [EditorAgentEvent] = []
    @State private var status = "Loading conversation…"
    @State private var loadTask: Task<Void, Never>?
    let workspaceURL: URL
    let sessionID: String

    var body: some View {
        VStack {
            if !status.isEmpty {
                Text(status).font(MobileEditorFont.font(size: 14)).foregroundColor(theme.editorColors.muted).padding(22)
            }
            transcript
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.editorColors.background)
        .onAppear {
            loadTask = Task { @MainActor in
                do {
                    let loaded = try await MobileEditorSessionStore(workspaceURL: workspaceURL).events(id: sessionID)
                    try Task.checkCancellation()
                    _ = interfaces.prepare(sessionID: sessionID, projectURL: workspaceURL, events: loaded, identity: nil)
                    events = loaded
                    status = loaded.isEmpty ? "This session has no messages." : ""
                } catch { if !Task.isCancelled { status = error.localizedDescription } }
            }
        }
        .onDisappear { loadTask?.cancel() }
    }

    private var transcript: some View {
        var view = EditorAgentTranscript(events: events, sessionID: sessionID)
        if let ui = interfaces.controller.sessions[sessionID] {
            view.a2uiPresentation = .init(session: ui, isEnabled: false, agentIdentity: ui.records.values.first?.agentIdentity)
        }
        view.scrollRespectsSafeArea = false
        view.scrollExtendsUnderNavigationBar = true
        return view
    }
}
#endif
