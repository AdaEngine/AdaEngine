import Foundation
import Testing

@testable import AdaEditor

@Suite("VR voice bubble", .serialized)
@MainActor
struct EditorVRVoiceTests {
    @Test("Dictation submits through the shared agent session and persists the transcript")
    func voicePrompt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = EditorProjectStore(storageURL: directory.appendingPathComponent("recent.json"))
        let reference = try store.createProject(named: "Voice", at: directory, template: .adaScript)
        let service = FakeEditorAgentService()
        let agent = EditorAgentViewModel(project: reference, service: service, notifications: EditorNotificationCenter())
        let draft = EditorVRVoiceDraft(agent: agent)
        draft.receiveTranscript("Move the selected cube to the left")
        #expect(agent.prompt == "Move the selected cube to the left")
        #expect(await draft.send())
        #expect(draft.response == "done")
        #expect(agent.prompt.isEmpty)
        let request = try #require(await service.recordedRequest())
        #expect(request.prompt == "Move the selected cube to the left")
        #expect(request.prompt == draft.submittedText)
        let session = try #require(agent.activeSession)
        let saved = try await EditorAgentSessionStore(projectURL: URL(fileURLWithPath: reference.path)).loadSession(id: session.id)
        #expect(saved.events.contains { $0.message?.role == .user })
        #expect(MobileEditorVoiceContent.reply(in: saved.events) == "done")
    }

    @Test("Whitespace does not start an agent turn and failed turns are not spoken")
    func emptyAndFailed() async throws {
        let agent = EditorAgentViewModel(project: nil, service: FakeEditorAgentService(), notifications: EditorNotificationCenter())
        let draft = EditorVRVoiceDraft(agent: agent)
        draft.receiveTranscript("  \n ")
        #expect(!(await draft.send()))
        #expect(draft.response == nil && draft.submittedText == nil)
        draft.receiveTranscript("Hello")
        #expect(!(await draft.send()))
        #expect(agent.prompt == "Hello")
    }

    @Test("A failed provider retains the dictated prompt for retry and produces no spoken reply")
    func failedProvider() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = EditorProjectStore(storageURL: directory.appendingPathComponent("recent.json"))
        let reference = try store.createProject(named: "VoiceFailure", at: directory, template: .adaScript)
        let agent = EditorAgentViewModel(project: reference, service: FailingVoiceAgentService(), notifications: EditorNotificationCenter())
        let draft = EditorVRVoiceDraft(agent: agent)
        draft.receiveTranscript("Keep this prompt")
        #expect(!(await draft.send()))
        #expect(agent.prompt == "Keep this prompt")
        #expect(draft.response == nil)
        #expect(agent.activityState == .failed)
    }

    @Test("Incoming dictation cannot overwrite the composer while another turn runs")
    func busyDraft() {
        let agent = EditorAgentViewModel(project: nil, service: FakeEditorAgentService(), notifications: EditorNotificationCenter())
        let draft = EditorVRVoiceDraft(agent: agent)
        agent.prompt = "Keep this draft"
        agent.isSending = true
        draft.receiveTranscript("Late microphone callback")
        #expect(agent.prompt == "Keep this draft")
    }
}

private actor FailingVoiceAgentService: EditorAgentServicing {
    func connect(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentSessionConfiguration { .empty }
    func send(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult { throw EditorAgentServiceError.providerFailure("Provider unavailable") }
    func setConfiguration(sessionID: String, selectorID: String, valueID: String) async throws -> EditorAgentSessionConfiguration { .empty }
    func resolvePermission(requestID: String, optionID: String?) async {}
    func cancel(sessionID: String) async {}
    func shutdown() async {}
}
