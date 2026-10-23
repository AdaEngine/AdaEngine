import Foundation
import Testing

@testable import AdaEditor

@MainActor
@Suite("Agent prompt suggestions", .timeLimit(.minutes(1)))
struct EditorAgentPromptSuggestionTests {
    @Test("Typing is debounced and only the latest authored draft reaches the provider")
    func debounce() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .milliseconds(30))
        controller.update(snapshot("Make"))
        controller.update(snapshot("Make it"))
        #expect(await service.requests.isEmpty)
        await service.waitForRequests(1)
        #expect(await service.requests.map(\.draft) == ["Make it"])
        await service.resolve(0, with: ["Make it move", "Make it jump"])
        try await settle { controller.suggestions == ["Make it move"] }
        #expect(controller.purpose == .completion)
    }

    @Test("Only visible, idle, end-of-draft natural text is eligible")
    func eligibility() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        var value = snapshot("Make it")
        value.isVisible = false
        controller.update(value)
        value.isVisible = true
        value.isSending = true
        controller.update(value)
        value.isSending = false
        value.context.caretOffset = 2
        controller.update(value)
        controller.update(snapshot("abc"))
        controller.update(snapshot("/compact preserve the plan"))
        controller.update(snapshot("@file.swift"))
        value = snapshot("Use @file")
        value.hasStructuredCompletion = true
        controller.update(value)
        try await Task.sleep(for: .milliseconds(20))
        #expect(await service.requests.isEmpty)
        #expect(controller.suggestions.isEmpty)
    }

    @Test("An obsolete cancellation-ignoring result cannot replace a newer draft")
    func lateDraftResult() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        controller.update(snapshot("Make it"))
        await service.waitForRequests(1)
        controller.update(snapshot("Change it"))
        await service.waitForRequests(2)
        await service.resolve(1, with: ["Change it slowly"])
        try await settle { controller.suggestions == ["Change it slowly"] }
        await service.resolve(0, with: ["Make it fast"])
        try await Task.sleep(for: .milliseconds(10))
        #expect(controller.suggestions == ["Change it slowly"])
    }

    @Test("Session, language, mode, caret and visibility invalidate in-flight results", arguments: ["session", "language", "mode", "caret", "hidden", "sending"])
    func invalidation(_ change: String) async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        var value = snapshot("Make it")
        controller.update(value)
        await service.waitForRequests(1)
        switch change {
        case "session": value.context.sessionID = "other"
        case "language": value.context.languageCode = "ru"
        case "mode": value.context.mode = "ask"
        case "caret": value.context.caretOffset = 1
        case "hidden": value.isVisible = false
        default: value.isSending = true
        }
        controller.update(value)
        await service.resolve(0, with: ["Make it fast"])
        try await Task.sleep(for: .milliseconds(10))
        #expect(controller.suggestions.isEmpty)
        if change == "session" || change == "language" || change == "mode" {
            await service.waitForRequests(2)
            await service.resolve(1, with: [])
        }
    }

    @Test("Dismissal survives refreshed status and restored identical snapshots")
    func dismissal() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        var value = snapshot("Make it")
        controller.update(value)
        await service.waitForRequests(1)
        controller.dismiss()
        await service.resolve(0, with: ["Make it fast"])
        value.isVisible = false
        controller.update(value)
        value.isVisible = true
        controller.update(value)
        controller.update(value)
        try await Task.sleep(for: .milliseconds(10))
        #expect(controller.suggestions.isEmpty)
        #expect(await service.requests.count == 1)
        controller.update(snapshot("Make it better"))
        await service.waitForRequests(2)
        await service.resolve(1, with: ["Make it better now"])
        try await settle { controller.suggestions == ["Make it better now"] }
    }

    @Test("Completion results preserve whitespace and Unicode authored prefix defensively")
    func exactPrefix() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        controller.update(snapshot("  Сделай 🦊"))
        await service.waitForRequests(1)
        await service.resolve(0, with: ["Сделай 🦊 быстрее", "  Сделай 🦊", "  Сделай 🦊 быстрее", "  Сделай 🦊 выше"])
        try await settle { !controller.suggestions.isEmpty }
        #expect(controller.suggestions == ["  Сделай 🦊 быстрее"])
        #expect(!controller.canInsert("Сделай 🦊 быстрее"))
        #expect(controller.canInsert("  Сделай 🦊 быстрее"))
        controller.dismiss()
        #expect(!controller.canInsert("  Сделай 🦊 быстрее"))
    }

    @Test("Canonically equivalent edits still invalidate byte-exact completion prefixes")
    func canonicalEdit() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        controller.update(snapshot("Cafe\u{301}"))
        await service.waitForRequests(1)
        await service.resolve(0, with: ["Café moves", "Cafe\u{301} moves"])
        try await settle { !controller.suggestions.isEmpty }
        #expect(controller.suggestions.first?.utf8.elementsEqual("Cafe\u{301} moves".utf8) == true)
        controller.update(snapshot("Café"))
        #expect(controller.suggestions.isEmpty)
        await service.waitForRequests(2)
        await service.resolve(1, with: ["Café jumps"])
        try await settle { controller.suggestions == ["Café jumps"] }
    }

    @Test("Follow-ups require a completed reply and retain at most three distinct drafts")
    func followUps() async throws {
        let service = ControlledPromptSuggestionService()
        let controller = EditorAgentPromptSuggestions(service: service, debounce: .zero)
        var value = snapshot("")
        controller.update(value)
        value.context.completedReplyID = "done"
        controller.update(value)
        await service.waitForRequests(1)
        #expect(await service.requests.first?.purpose == .followUps)
        await service.resolve(0, with: ["Explain it", "", "Explain it", "Add a test", "Show an example", "One more"])
        try await settle { controller.suggestions.count == 3 }
        #expect(controller.suggestions == ["Explain it", "Add a test", "Show an example"])
        #expect(controller.purpose == .followUps)
    }

    @Test("Only exact successful terminal evidence after the latest user enables follow-ups")
    func terminalEvidence() {
        let successful = completedSession()
        #expect(EditorAgentViewModel.completedSuggestionReply(in: successful) == "done")
        var session = successful
        session.events.removeLast()
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session.events.append(.init(kind: .runStatus, title: "Interrupted", details: "cancelled"))
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session = successful
        session.events.append(.init(kind: .error, title: "Agent failed", isSuccessful: false))
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session = successful
        session.events.append(message("pending", role: .user, text: "Another request"))
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session = successful
        session.events[2].title = "Almost Done"
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session = successful
        session.events[2].isSuccessful = false
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session = successful
        session.events.remove(at: 1)
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == nil)
        session = successful
        session.events.insert(.init(kind: .toolResult, title: "Tool failed", isSuccessful: false), at: 1)
        #expect(EditorAgentViewModel.completedSuggestionReply(in: session) == "done")
    }

    @Test("Direct prompt writes refresh and accepting a suggestion leaves an editable focused draft")
    func viewModelAcceptance() async throws {
        let service = ControlledPromptSuggestionService()
        let model = makeModel(service)
        model.activeSession = .init(id: "session")
        model.panelDidAppear()
        model.prompt = "Make it"
        await service.waitForRequests(1)
        await service.resolve(0, with: ["Make it\nmove faster"])
        try await settle { !model.promptSuggestions.suggestions.isEmpty }
        model.insertPromptSuggestion("Make it\nmove faster")
        #expect(model.prompt == "Make it\nmove faster")
        #expect(model.promptCompletionFocus?.start.line == 1)
        #expect(model.promptCompletionFocus?.start.column == "move faster".count)
        #expect(model.promptCompletionFocus?.start == model.promptCompletionFocus?.end)
        #expect(!model.isSending)
        #expect(model.activeSession?.events.isEmpty == true)
        model.refreshPromptSuggestions()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.promptSuggestions.suggestions.isEmpty)
        #expect(await service.requests.count == 1)
    }

    @Test("Restored completed sessions offer follow-ups and status refresh does not undo dismissal")
    func restoredSession() async throws {
        let service = ControlledPromptSuggestionService()
        let model = makeModel(service)
        model.activeSession = completedSession()
        model.panelDidAppear()
        await service.waitForRequests(1)
        await service.resolve(0, with: ["Show a test"])
        try await settle { model.promptSuggestions.suggestions == ["Show a test"] }
        model.dismissPromptSuggestions()
        model.activeSession?.events.append(.init(kind: .runStatus, title: "Connected"))
        model.activeSession = completedSession()
        model.refreshPromptSuggestions()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.promptSuggestions.suggestions.isEmpty)
        #expect(await service.requests.count == 1)
    }

    @Test("A successful live turn persists before enabling follow-ups after sending ends")
    func persistedLiveTurn() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Suggestions"), at: root)
        let service = ControlledPromptSuggestionService()
        let model = EditorAgentViewModel(
            project: .init(name: "Suggestions", path: root.path),
            settings: EditorAgentSettingsStore(),
            service: FakeEditorAgentService(),
            suggestionService: service
        )
        await model.loadSessions()
        model.panelDidAppear()
        model.prompt = "Make it move"
        await model.sendPromptAsync()
        #expect(!model.isSending)
        let sessionID = try #require(model.activeSession?.id)
        let restored = try await EditorAgentSessionStore(projectURL: root).loadSession(id: sessionID)
        #expect(EditorAgentViewModel.completedSuggestionReply(in: restored) != nil)
        await service.waitForRequests(1)
        #expect(await service.requests.first?.purpose == .followUps)
        await service.resolve(0, with: ["Show how it works"])
        try await settle { model.promptSuggestions.suggestions == ["Show how it works"] }
        model.panelDidDisappear()
    }

    private func snapshot(_ draft: String) -> EditorAgentPromptSuggestions.Snapshot {
        .init(context: .init(sessionID: "session", draft: draft, caretOffset: draft.count, mode: "build", languageCode: "en", messages: []))
    }

    private func message(_ id: String, role: EditorAgentRole, text: String) -> EditorAgentEvent {
        .init(id: id, kind: .message, message: .init(role: role, segments: [.init(kind: .text, text: text)]))
    }

    private func completedSession() -> EditorAgentSession {
        .init(id: "session", events: [
            message("user", role: .user, text: "Make it move"),
            message("assistant", role: .assistant, text: "It now moves."),
            .init(id: "done", kind: .runStatus, title: "Done", details: "end_turn"),
        ])
    }

    private func makeModel(_ service: ControlledPromptSuggestionService) -> EditorAgentViewModel {
        EditorAgentViewModel(project: nil, settings: EditorAgentSettingsStore(), service: FakeEditorAgentService(), suggestionService: service)
    }

    private func settle(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Suggestion state did not settle")
    }
}

/// Deliberately ignores cancellation so tests exercise ownership checks after generation.
private actor ControlledPromptSuggestionService: EditorAgentSuggestionServing {
    private(set) var requests: [EditorAgentSuggestionRequest] = []
    private var replies: [Int: CheckedContinuation<[String], Never>] = [:]
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func suggestions(for request: EditorAgentSuggestionRequest) async -> [String] {
        let index = requests.count
        requests.append(request)
        return await withCheckedContinuation { continuation in
            replies[index] = continuation
            let ready = waiters.filter { $0.0 <= requests.count }
            waiters.removeAll { $0.0 <= requests.count }
            for waiter in ready { waiter.1.resume() }
        }
    }

    func waitForRequests(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func resolve(_ index: Int, with suggestions: [String]) {
        replies.removeValue(forKey: index)?.resume(returning: suggestions)
    }
}
