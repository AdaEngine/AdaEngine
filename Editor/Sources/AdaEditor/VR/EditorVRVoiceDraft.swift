import Foundation
import Observation

/// Voice and keyboard compose the same project agent prompt and use its normal session/history path.
@Observable
@MainActor
final class EditorVRVoiceDraft {
    let agent: EditorAgentViewModel
    private(set) var submittedText: String?
    private(set) var response: String?
    private(set) var isSubmitting = false

    init(agent: EditorAgentViewModel) { self.agent = agent }

    func receiveTranscript(_ text: String) {
        guard !agent.isSending, !isSubmitting else {
            return
        }
        agent.promptBinding.wrappedValue = text
    }

    @discardableResult
    func send() async -> Bool {
        guard agent.canSend, !isSubmitting else {
            return false
        }
        let outgoingText = agent.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        defer { isSubmitting = false }
        if agent.activeSession == nil {
            do { try await agent.createSession(connectAutomatically: false) } catch {
                agent.statusMessage = error.localizedDescription
                return false
            }
        }
        guard agent.activeSession != nil else {
            return false
        }
        agent.promptBinding.wrappedValue = outgoingText
        submittedText = outgoingText
        response = nil
        await agent.sendPromptAsync()
        guard agent.activityState == .completed else {
            if agent.prompt.isEmpty { agent.promptBinding.wrappedValue = submittedText ?? "" }
            return false
        }
        response = MobileEditorVoiceContent.reply(in: agent.activeSession?.events ?? [])
        return response != nil
    }
}
