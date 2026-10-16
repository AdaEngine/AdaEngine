#if os(Android)
@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

@MainActor
final class MobileCodexAuthorizationBrowser {
    func present(url: URL, onDismiss: @escaping @MainActor () -> Void) -> Bool {
        Application.shared.openURL(url)
    }
    func dismiss() {}
}

@MainActor
enum MobileEditorImagePaste {
    static func files() throws -> [URL] { [] }
}

struct MobileEditorGameFeedbackInput: View {
    @Binding var text: String
    let textColor: Color
    var body: some View {
        TextField("Describe the change…", text: _text)
            .foregroundColor(textColor)
    }
}

@Observable
@MainActor
final class MobileEditorPromptDictation {
    private(set) var isStarting = false
    private(set) var isRecording = false
    let isPreparingModel = false
    let audioLevel: Float = 0
    private(set) var errorMessage: String?
    private var requestID: Int64?

    func start(initialText: String = "", onTranscript: @escaping @MainActor (String) -> Void) {
        stop()
        errorMessage = nil
        isRecording = true
        requestID = AndroidStudioHost.request("dictate") { [weak self] reply in
            guard let self else { return }
            self.requestID = nil
            self.isRecording = false
            self.errorMessage = reply.error
            if let text = reply.text, !text.isEmpty {
                onTranscript(initialText.isEmpty ? text : initialText + " " + text)
            }
        }
    }

    func finish() { stop() }
    func stop() {
        if let requestID { AndroidStudioHost.cancel(requestID) }
        requestID = nil
        isStarting = false
        isRecording = false
    }
}

@Observable
@MainActor
final class MobileEditorVoiceSession {
    let dictation = MobileEditorPromptDictation()
    private(set) var isSpeaking = false
    private(set) var errorMessage: String?
    private var speechRequest: Int64?

    func listen(initialText: String, onTranscript: @escaping @MainActor (String) -> Void) {
        stopSpeaking()
        errorMessage = nil
        dictation.start(initialText: initialText, onTranscript: onTranscript)
    }
    func speak(_ text: String) {
        stop()
        errorMessage = nil
        isSpeaking = true
        speechRequest = AndroidStudioHost.request("speak", text: text) { [weak self] reply in
            self?.isSpeaking = false
            self?.speechRequest = nil
            self?.errorMessage = reply.error
        }
    }
    func finishListening() { dictation.finish() }
    func stop() { dictation.stop(); stopSpeaking() }

    private func stopSpeaking() {
        if let speechRequest { AndroidStudioHost.cancel(speechRequest) }
        speechRequest = nil
        isSpeaking = false
        _ = try? AndroidStudioHost.call("speech.stop")
    }
}
#endif
