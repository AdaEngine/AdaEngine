@testable import AdaEditor
import Foundation
import Testing

#if os(macOS)
@Suite("Editor agent ACP streaming", .serialized)
struct EditorAgentStreamingTests {
    @Test("connected session keeps model selection and delivers deltas before prompt completion")
    func streamingProcess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AgentStream-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let script = root.appendingPathComponent("agent.py")
        try Self.agentScript.write(to: script, atomically: true, encoding: .utf8)
        var project = ProjectSystem.defaultProject(projectName: "Streaming")
        project.ai.agent.enabled = true
        project.ai.agent.target = AdaProjectAgentTarget(command: "/usr/bin/python3", arguments: [script.path])
        let request = EditorAgentRunRequest(
            project: project, projectURL: root, session: EditorAgentSession(), mode: .build,
            prompt: "test", attachments: [], sceneContext: nil, codeSelection: nil, skills: []
        )
        let service = EditorACPAgentService()
        let recorder = StreamingRecorder()
        let finished = root.appendingPathComponent("finished")
        let onEvent: @Sendable (EditorAgentEvent) async -> Void = { event in
            await recorder.record(event, beforeCompletion: !FileManager.default.fileExists(atPath: finished.path))
        }
        do {
            let connected = try await service.connect(request, onEvent: onEvent, onProjectFileChanged: { _ in })
            #expect(connected.selectors.first?.currentValueID == "a")
            let selected = try await service.setConfiguration(sessionID: request.session.id, selectorID: "model", valueID: "b")
            #expect(selected.selectors.first?.currentValueID == "b")
            let reconnected = try await service.connect(request, onEvent: onEvent, onProjectFileChanged: { _ in })
            #expect(reconnected.selectors.first?.currentValueID == "b")
            let result = try await service.send(request, onEvent: onEvent, onProjectFileChanged: { _ in })
            let chunks = await recorder.chunks
            #expect(chunks.map { $0.message?.segments.first?.text ?? "" } == ["Hello", " world"])
            #expect(Set(chunks.map(\.id)).count == 1)
            #expect(await recorder.receivedBeforeCompletion)
            #expect(result.assistantText == "Hello world")
            #expect(result.configuration.selectors.first?.currentValueID == "c")
            #expect(await recorder.configurations.last?.selectors.first?.currentValueID == "c")
            await service.shutdown()
        } catch {
            await service.shutdown()
            throw error
        }
    }

    private static let agentScript = #"""
    import json, sys, time
    def emit(value):
        print(json.dumps(value), flush=True)
    def options(current):
        return [{"id":"model","name":"Model","category":"model","type":"select","currentValue":current,
                 "options":[{"value":v,"name":v.upper()} for v in ["a","b","c"]]}]
    def update(value):
        emit({"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"session","update":value}})
    for line in sys.stdin:
        req = json.loads(line)
        method = req.get("method")
        if method == "initialize":
            result = {"protocolVersion":1,"agentCapabilities":{"loadSession":False},"agentInfo":{"name":"test","version":"1"}}
        elif method == "session/new":
            result = {"sessionId":"session","configOptions":options("a")}
        elif method == "session/set_config_option":
            result = {"configOptions":options(req["params"]["value"])}
        elif method == "session/prompt":
            for text in ["Hello", " world"]:
                update({"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":text}})
                time.sleep(0.2)
            update({"sessionUpdate":"config_option_update","configOptions":options("c")})
            time.sleep(0.2)
            open("finished", "w").close()
            result = {"stopReason":"end_turn"}
        else:
            result = {}
        if "id" in req:
            emit({"jsonrpc":"2.0","id":req["id"],"result":result})
    """#
}

private actor StreamingRecorder {
    var chunks: [EditorAgentEvent] = []
    var configurations: [EditorAgentSessionConfiguration] = []
    var receivedBeforeCompletion = false

    func record(_ event: EditorAgentEvent, beforeCompletion: Bool) {
        if event.isDelta == true {
            chunks.append(event)
            receivedBeforeCompletion = receivedBeforeCompletion || beforeCompletion
        }
        if let configuration = event.configuration { configurations.append(configuration) }
    }
}
#endif
