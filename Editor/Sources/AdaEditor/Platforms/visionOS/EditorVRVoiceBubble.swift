#if os(visionOS)
    import SwiftUI

    @available(visionOS 26.0, *)
    struct EditorVRVoiceBubble: SwiftUI.View {
        let workspace: EditorVRWorkspace
        @SwiftUI.Environment(\.dismissWindow) private var dismissWindow

        var body: some SwiftUI.View {
            if workspace.project != nil, let draft = workspace.voiceDraft {
                EditorVRVoiceContent(draft: draft, workspace: workspace)
                    .id(workspace.project?.id)
                    .onAppear { workspace.setPanel(.voice, visible: true) }
                    .onDisappear { workspace.setPanel(.voice, visible: false) }
            } else {
                SwiftUI.Color.clear.onAppear { dismissWindow(id: EditorVRPanel.voice.windowID) }
            }
        }
    }

    @available(visionOS 26.0, *)
    private struct EditorVRVoiceContent: SwiftUI.View {
        let draft: EditorVRVoiceDraft
        let workspace: EditorVRWorkspace
        @SwiftUI.State private var voice = MobileEditorVoiceSession()
        @SwiftUI.State private var showsSettings = false
        @SwiftUI.State private var isVisible = false
        @SwiftUI.FocusState private var editingTranscript: Bool
        @SwiftUI.Environment(\.scenePhase) private var scenePhase

        private var capturing: Bool { voice.dictation.isStarting || voice.dictation.isRecording }
        private var working: Bool { draft.isSubmitting || draft.agent.isSending }
        private var activity: MobileVoiceOrbActivity {
            if capturing {
                return .listening
            }
            if voice.isSpeaking {
                return .speaking
            }
            return working ? .working : .idle
        }
        private var errorMessage: String? {
            if let error = voice.dictation.errorMessage ?? voice.errorMessage {
                return error
            }
            if case .failed(let error) = draft.agent.connectionState {
                return error
            }
            return draft.agent.statusMessage
        }
        private var status: String {
            if voice.dictation.isStarting {
                return "Starting microphone…"
            }
            if capturing {
                return "Listening…"
            }
            if voice.isSpeaking {
                return "Ada is speaking…"
            }
            if working {
                return "Ada is working…"
            }
            return "Speak or write to Ada"
        }

        var body: some SwiftUI.View {
            SwiftUI.VStack(spacing: 12) {
                SwiftUI.Button(action: toggleListening) {
                    EditorVRVoiceOrb(activity: activity, audioLevel: voice.dictation.audioLevel)
                        .allowsHitTesting(false)
                }
                .buttonStyle(.plain)
                .contentShape(SwiftUI.Circle())
                .hoverEffect(.highlight)
                .accessibilityLabel(capturing ? "Stop listening" : "Speak to Ada")
                .accessibilityIdentifier("AdaEditor.VR.VoiceBubble")
                .disabled(working)

                SwiftUI.Text(status).font(.caption).padding(.horizontal, 14).padding(.vertical, 8)
                    .glassBackgroundEffect(in: SwiftUI.Capsule())
                SwiftUI.TextField("Your prompt", text: SwiftUI.Binding(get: { draft.agent.prompt }, set: { draft.receiveTranscript($0) }), axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder).focused($editingTranscript)
                    .accessibilityIdentifier("AdaEditor.VR.VoiceTranscript")
                    .disabled(working)
                if let response = draft.response {
                    SwiftUI.ScrollView {
                        SwiftUI.Text(response).font(.callout).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }.frame(maxHeight: 120).accessibilityIdentifier("AdaEditor.VR.BubbleReply")
                }
                if let error = errorMessage {
                    SwiftUI.Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                SwiftUI.HStack(spacing: 20) {
                    SwiftUI.Button {
                        voice.stop()
                        editingTranscript = true
                    } label: {
                        SwiftUI.Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Write to Ada")
                    .accessibilityIdentifier("AdaEditor.VR.WritePrompt")
                    .contextMenu {
                        SwiftUI.Button("Open Agent Chat") {
                            voice.stop()
                            workspace.activatedPalmPanel = .agent
                        }
                    }
                    SwiftUI.Button(action: toggleListening) {
                        SwiftUI.Image(systemName: capturing || voice.isSpeaking ? "stop.fill" : "mic.fill")
                    }.disabled(working).accessibilityLabel(capturing ? "Stop listening" : "Start listening")
                    SwiftUI.Button {
                        send()
                    } label: {
                        SwiftUI.Image(systemName: "arrow.up")
                    }
                    .disabled(working || !draft.agent.canSend).accessibilityLabel("Send prompt")
                    .accessibilityIdentifier("AdaEditor.VR.SendVoicePrompt")
                    SwiftUI.Button {
                        voice.stop()
                        showsSettings = true
                    } label: {
                        SwiftUI.Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Voice settings")
                }.buttonStyle(.borderless).controlSize(.large).padding(12)
                    .glassBackgroundEffect(in: SwiftUI.Capsule())
            }
            .frame(width: 300).padding(10)
            .sheet(isPresented: $showsSettings) { EditorVRVoiceSettings() }
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                voice.stop()
                workspace.setTextInputFocus(false, host: EditorVRPanel.voice.windowID)
                workspace.setPanelHover(false, panel: .voice)
            }
            .onChange(of: capturing) { _, _ in updateInputFocus() }
            .onChange(of: editingTranscript) { _, _ in updateInputFocus() }
            .onChange(of: showsSettings) { _, _ in updateInputFocus() }
            .onHover { workspace.setPanelHover($0, panel: .voice) }
            .onChange(of: scenePhase) { _, phase in if phase != .active { voice.stop() } }
        }

        private func updateInputFocus() {
            workspace.setTextInputFocus(capturing || editingTranscript || showsSettings, host: EditorVRPanel.voice.windowID)
        }
        private func toggleListening() {
            if voice.isSpeaking { voice.stop() } else if capturing { voice.finishListening() } else if !working { voice.listen(initialText: draft.agent.prompt, onTranscript: { draft.receiveTranscript($0) }) }
        }
        private func send() {
            voice.stop()
            draft.agent.setSceneContext(workspace.document.flatMap { EditorAgentSceneContext(document: $0) })
            Task { @MainActor in
                if await draft.send(), let response = draft.response, workspace.project != nil, isVisible, scenePhase == .active {
                    voice.speak(response)
                }
            }
        }
    }
#endif
