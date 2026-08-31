import Foundation
import GravityLanguageCore
import GravityLanguageServerProtocol
import Testing

@Suite("Gravity language server")
struct GravityLanguageServerTests {
    @Test("Completion understands document types and Ada query values")
    func semanticCompletion() throws {
        let service = GravityLanguageService()
        let source = """
        class MovementSystem {
            var speed = 1;
            func update(deltaTime, queries) {}
        }
        func main() {
            var system = MovementSystem();
            system.up
        }
        """
        let methodItems = service.completions(
            text: source,
            position: GravitySourcePosition(line: 6, utf16Column: 13)
        )
        let update = try #require(methodItems.first { $0.label == "update" })
        #expect(update.insertText == "update()")
        #expect(update.replacementRange.start == GravitySourcePosition(line: 6, utf16Column: 11))

        let querySource = """
        @query(Transform)
        var movers;
        func update(context) {
            for (var entity in movers) {
                entity.i
            }
        }
        """
        let queryItems = service.completions(
            text: querySource,
            position: GravitySourcePosition(line: 4, utf16Column: 16)
        )
        #expect(queryItems.contains { $0.label == "id" })
    }

    @Test("Completion uses symbols from real workspace files")
    func workspaceCompletion() throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GravityLSP-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "class SharedSystem { func tick() {} }".write(
            to: projectURL.appendingPathComponent("Shared.ada"),
            atomically: true,
            encoding: .utf8
        )

        let workspace = GravityWorkspace()
        workspace.configure(rootURIs: [projectURL.absoluteString])
        let currentURL = projectURL.appendingPathComponent("Current.ada")
        workspace.open(uri: currentURL.absoluteString, text: "SharedSystem.ti", version: 1)
        let items = workspace.completions(
            uri: currentURL.absoluteString,
            position: GravitySourcePosition(line: 0, utf16Column: 15)
        )

        #expect(items.contains { $0.label == "tick" && $0.insertText == "tick()" })
    }

    @Test("Diagnostics report unfinished source without rejecting completion")
    func tolerantDiagnostics() {
        let service = GravityLanguageService()
        let source = "@system(scheduler: \"update\")\nclass Movement {\n    @que"
        let analysis = service.analyze(text: source)
        let completions = service.completions(
            text: source,
            position: GravitySourcePosition(line: 2, utf16Column: 8)
        )

        #expect(analysis.diagnostics.contains { $0.message == "Unclosed '{'" })
        #expect(completions.contains { $0.label == "query" })
    }

    @Test("Completion keeps type members while the class is unfinished")
    func unfinishedTypeCompletion() {
        let service = GravityLanguageService()
        let source = """
        class MovementSystem {
            func update() {}
            func run() {
                this.up
        """
        let analysis = service.analyze(text: source)
        let completions = service.completions(
            text: source,
            position: GravitySourcePosition(line: 3, utf16Column: 15)
        )

        #expect(analysis.diagnostics.contains { $0.message == "Unclosed '{'" })
        #expect(completions.contains { $0.label == "update" })
    }

    @Test("LSP lifecycle publishes diagnostics and returns completion")
    func protocolLifecycle() throws {
        let session = GravityLanguageServerSession()
        let initialize = session.handle([
            "id": 1,
            "jsonrpc": "2.0",
            "method": "initialize",
            "params": ["rootUri": NSNull()]
        ])
        let initializeResponse = try #require(initialize.outgoingMessages.first)
        let initializeResult = try #require(initializeResponse["result"] as? [String: Any])
        let capabilities = try #require(initializeResult["capabilities"] as? [String: Any])
        #expect(capabilities["positionEncoding"] as? String == "utf-16")

        let uri = "file:///tmp/Movement.ada"
        let opened = session.handle([
            "jsonrpc": "2.0",
            "method": "textDocument/didOpen",
            "params": [
                "textDocument": [
                    "languageId": "gravity",
                    "text": "@que",
                    "uri": uri,
                    "version": 1
                ]
            ]
        ])
        let diagnosticsNotification = try #require(opened.outgoingMessages.first)
        #expect(diagnosticsNotification["method"] as? String == "textDocument/publishDiagnostics")

        let completion = session.handle([
            "id": 2,
            "jsonrpc": "2.0",
            "method": "textDocument/completion",
            "params": [
                "position": ["character": 4, "line": 0],
                "textDocument": ["uri": uri]
            ]
        ])
        let response = try #require(completion.outgoingMessages.first)
        let result = try #require(response["result"] as? [String: Any])
        let items = try #require(result["items"] as? [[String: Any]])
        #expect(items.contains { $0["label"] as? String == "query" })

        let shutdown = session.handle(["id": 3, "jsonrpc": "2.0", "method": "shutdown"])
        #expect(shutdown.outgoingMessages.count == 1)
        #expect(session.handle(["jsonrpc": "2.0", "method": "exit"]).exitCode == 0)
    }

    @Test("Framer accepts split and consecutive LSP messages")
    func messageFraming() throws {
        let first = try GravityLSPMessageFramer.frame(["id": 1, "jsonrpc": "2.0", "method": "shutdown"])
        let second = try GravityLSPMessageFramer.frame(["jsonrpc": "2.0", "method": "exit"])
        let combined = first + second
        let splitIndex = combined.count / 3
        var framer = GravityLSPMessageFramer()

        #expect(try framer.append(combined.prefix(splitIndex)).isEmpty)
        let payloads = try framer.append(combined.dropFirst(splitIndex))
        #expect(payloads.count == 2)
        let firstMessage = try #require(JSONSerialization.jsonObject(with: payloads[0]) as? [String: Any])
        #expect(firstMessage["method"] as? String == "shutdown")
    }

    @Test("Framer rejects negative content lengths")
    func negativeContentLength() {
        var framer = GravityLSPMessageFramer()
        #expect(throws: GravityLSPFramingError.invalidContentLength) {
            try framer.append(Data("Content-Length: -1\r\n\r\n".utf8))
        }
    }
}
