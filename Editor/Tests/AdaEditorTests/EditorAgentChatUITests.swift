@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import AdaInput
@_spi(Internal) import AdaUI
import Foundation
import Math
import Testing

@Suite("Editor agent chat UI", .serialized)
@MainActor
struct EditorAgentChatUITests {
    private func makeContainer(_ model: EditorAgentViewModel) -> UIContainerView<EditorAgentSidebar> {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "AgentChatUI")))
        }
        let container = UIContainerView(rootView: EditorAgentSidebar(viewModel: model))
        container.frame = Rect(x: 0, y: 0, width: 560, height: 820)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        return container
    }

    @Test("streamed text relayouts the existing message before completion")
    func streamingRelayout() async throws {
        let model = EditorAgentViewModel(project: nil, service: FakeEditorAgentService())
        model.activeSession = EditorAgentSession(title: "Streaming")
        model.activeSession?.events = [EditorAgentEvent(
            id: "stream", kind: .message,
            message: EditorAgentMessage(role: .assistant, segments: [.init(kind: .text, text: "First delta")])
        )]
        model.isSending = true
        let container = makeContainer(model)
        let selector = UINodeSelector.accessibilityIdentifier("AdaEditor.Agent.Event.stream")
        let before = try container.uiNode(matching: selector)
        model.activeSession?.events[0].message?.segments[0].text = String(repeating: "A streamed line of text.\n", count: 10)
        for _ in 0..<20 { await Task.yield() }
        container.layoutIfNeeded()
        let after = try container.uiNode(matching: selector)
        #expect(after.runtimeId == before.runtimeId)
        #expect(after.absoluteFrame.height > before.absoluteFrame.height)
        #expect(model.isSending)
    }

    @Test("service details collapse and composer has no empty context gap")
    func disclosureAndComposer() async throws {
        let model = EditorAgentViewModel(project: nil, service: FakeEditorAgentService())
        model.activeSession = EditorAgentSession(title: "Layout")
        model.activeSession?.events = [EditorAgentEvent(id: "status", kind: .runStatus, title: "Session updated", details: String(repeating: "Details\n", count: 12))]
        let container = makeContainer(model)
        let selector = UINodeSelector.accessibilityIdentifier("AdaEditor.Agent.Event.status")
        let before = try container.uiNode(matching: selector)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Agent.ToggleEvent.status"))
        for _ in 0..<20 { await Task.yield() }
        container.layoutIfNeeded()
        let expanded = try container.uiNode(matching: selector)
        #expect(expanded.absoluteFrame.height > before.absoluteFrame.height)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Agent.ToggleEvent.status"))
        for _ in 0..<20 { await Task.yield() }
        container.layoutIfNeeded()
        #expect(try container.uiNode(matching: selector).absoluteFrame.height == before.absoluteFrame.height)
        let composer = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Agent.Composer"))
        let handle = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Agent.ResizeComposer"))
        #expect(handle.absoluteFrame.origin.y - composer.absoluteFrame.origin.y <= 10)
        #expect(composer.absoluteFrame.height < 190)
        _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Agent.Selector.model"))
    }
    @Test("composer drag changes editor height through pointer events")
    func resizeComposer() async throws {
        let container = makeContainer(EditorAgentViewModel(project: nil, service: FakeEditorAgentService()))
        let prompt = UINodeSelector.accessibilityIdentifier("AdaEditor.Agent.Prompt")
        let before = try container.uiNode(matching: prompt).absoluteFrame
        let handle = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Agent.ResizeComposer")).absoluteFrame
        let start = Point(handle.midX, handle.midY)
        for (phase, point) in [(MouseEvent.Phase.began, start), (.changed, start + Point(0, -72)), (.ended, start + Point(0, -72))] {
            container.onMouseEvent(MouseEvent(window: RID(), button: .left, mousePosition: point, phase: phase, modifierKeys: [], time: 0))
            for _ in 0..<10 { await Task.yield() }
        }
        container.layoutIfNeeded()
        let after = try container.uiNode(matching: prompt).absoluteFrame
        #expect(after.height == before.height + 72)
    }

    @Test("model control opens a menu with all advertised choices")
    func modelMenu() throws {
        let model = EditorAgentViewModel(project: nil, service: FakeEditorAgentService())
        model.sessionConfiguration = EditorAgentSessionConfiguration(agentName: "Test", selectors: [
            EditorAgentConfigurationSelector(id: "model", name: "Model", category: .model, currentValueID: "a", choices: [
                .init(id: "a", name: "Model A", description: nil),
                .init(id: "b", name: "Model B", description: nil)
            ], usesLegacyMethod: false)
        ])
        let container = makeContainer(model)
        var menu: ContextMenuPresentation?
        let previous = ContextMenuPresentationCenter.present
        ContextMenuPresentationCenter.present = { menu = $0 }
        defer { ContextMenuPresentationCenter.present = previous }
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Agent.Selector.model"))
        #expect(menu?.items.map(\.title) == ["✓ Model A", "Model B"])
    }

    @Test("short user bubble sits on the right and assistant text sits on the left")
    func messageAlignment() throws {
        let model = EditorAgentViewModel(project: nil, service: FakeEditorAgentService())
        model.activeSession = EditorAgentSession(events: [
            EditorAgentEvent(id: "user", kind: .message, message: EditorAgentMessage(role: .user, segments: [.init(kind: .text, text: "Hello")])),
            EditorAgentEvent(id: "assistant", kind: .message, message: EditorAgentMessage(role: .assistant, segments: [.init(kind: .text, text: "Hello")]))
        ])
        let container = makeContainer(model)
        let user = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Agent.EventContent.user")).absoluteFrame
        let assistant = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Agent.EventContent.assistant")).absoluteFrame
        #expect(user.minX > 280)
        #expect(assistant.minX < 30)
        #expect(user.width < 140)
    }

}
