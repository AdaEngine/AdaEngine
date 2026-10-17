import AdaStudioCore
import Foundation

extension StudioViewModel {
    func sendPrompt() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isAgentRunning else { return }
        guard !providerID.isEmpty, !modelID.isEmpty else { showsSettings = true; error = "Выберите доступного провайдера и модель."; return }
        guard billingMode != "byok" || !apiKey.isEmpty else { showsSettings = true; error = "Введите API-ключ. Он используется Cloud-прокси и хранится только в этой вкладке."; return }
        prompt = ""; isAgentRunning = true; agentText = ""
        agentTask = Task {
            defer { isAgentRunning = false; agentTask = nil }
            do {
                if document == nil { await create(.game2D, title: String(text.prefix(60))) }
                guard let document else { return }
                // Do not replay a tool whose side effect may already have happened before tab closure.
                let answered = Set(document.snapshot.messages.compactMap(\.toolCallID))
                for message in document.snapshot.messages {
                    for call in message.toolCalls ?? [] {
                        if let id = call["id"].string, !answered.contains(id) {
                            try document.append(.init(role: "tool", content: "Previous turn interrupted. Inspect the current project before continuing; this tool is not automatically replayed.", toolCallID: id))
                        }
                    }
                }
                var context = text
                if let entity = selectedEntity { context += "\n[Selected scene entity]\n" + entity.text }
                if let codeSelection, !codeSelection.isEmpty { context += "\n[Selected code in \(activeFile)]\n" + codeSelection }
                if !attachmentPaths.isEmpty { context += "\n[Project assets]\n" + attachmentPaths.joined(separator: "\n"); attachmentPaths = [] }
                try document.append(.init(role: "user", content: context)); changed()
                for _ in 0..<40 {
                    try Task.checkCancellation()
                    agentText = ""
                    var toolCalls: [StudioValue] = []
                    var complete = false
                    var failure: String?
                    let input: StudioValue = .object([
                        "operationID": .string(UUID().uuidString.lowercased()), "providerID": .string(providerID), "model": .string(modelID),
                        "billingMode": .string(billingMode), "apiKey": billingMode == "byok" ? .string(apiKey) : .null,
                        "messages": try StudioValue.decode(JSONEncoder().encode(contextMessages())), "tools": .array(Self.agentTools)
                    ])
                    try await browser.stream(path: "/v1/ai/generate", body: input.encoded()) { [weak self] event in
                        switch event["type"].string {
                        case "text": self?.agentText += event["text"].string ?? ""
                        case "tool": toolCalls.append(event["call"])
                        case "complete": complete = true
                        case "error": failure = event["message"].string ?? "Ошибка провайдера."
                        default: break
                        }
                    }
                    try Task.checkCancellation()
                    if let failure { throw StudioError.unavailable(failure) }
                    guard complete else { throw StudioError.unavailable("Ответ прерван. Продолжите с последнего сохранённого шага.") }
                    try document.append(.init(role: "assistant", content: agentText, toolCalls: toolCalls.isEmpty ? nil : toolCalls)); agentText = ""; changed()
                    if toolCalls.isEmpty { await save(checkpoint: true); return }
                    var capturedImages: [String] = []
                    for call in toolCalls {
                        try Task.checkCancellation()
                        guard let id = call["id"].string, let name = call["function"]["name"].string,
                              let encoded = call["function"]["arguments"].string else { throw StudioError.invalid("Некорректный вызов инструмента.") }
                        let result: StudioValue
                        do { result = try await runTool(name, arguments: StudioValue.decode(Data(encoded.utf8))) }
                        catch { result = .object(["error": .string(error.localizedDescription)]) }
                        try Task.checkCancellation()
                        guard self.document === document else { throw CancellationError() }
                        if name == "editor_play_capture", let image = result.string, image.hasPrefix("data:image/") {
                            try document.append(.init(role: "tool", content: "Game frame captured. The image follows in the next message.", toolCallID: id))
                            capturedImages.append(image)
                        } else { try document.append(.init(role: "tool", content: result.text, toolCallID: id)) }
                        changed()
                    }
                    if !capturedImages.isEmpty {
                        try document.append(.init(role: "user", content: "Current game camera frames. Verify them against the requested game.", images: Array(capturedImages.suffix(4))))
                        changed()
                    }
                }
                throw StudioError.unavailable("Достигнут лимит 40 шагов. Результат сохранён; можно продолжить новым сообщением.")
            } catch is CancellationError { status = "Агент остановлен" }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            await save(checkpoint: true)
        }
    }

    func stopAgent() { agentTask?.cancel(); browser.cancelRequests() }

    private func contextMessages() -> [StudioMessage] {
        let messages = document?.snapshot.messages ?? []
        var groups: [[StudioMessage]] = []
        for message in messages {
            if message.role == "tool", !groups.isEmpty { groups[groups.count - 1].append(message) }
            else { groups.append([message]) }
        }
        var result: [StudioMessage] = [], bytes = 0
        for group in groups.reversed() {
            let size = (try? JSONEncoder().encode(group).count) ?? 200_000
            guard bytes + size < 145_000 else { break }
            result = group + result; bytes += size
        }
        if result.count < messages.count {
            let goal = messages.last(where: { $0.role == "user" && $0.images == nil })?.content ?? "Continue the current project"
            result.insert(.init(role: "user", content: "Earlier context omitted. Inspect the current files and scene. Current goal: " + String(goal.prefix(4000))), at: 0)
        }
        return result
    }

    func runTool(_ name: String, arguments: StudioValue) async throws -> StudioValue {
        guard let document else { throw StudioError.invalid("Нет открытого проекта.") }
        switch name {
        case "editor_project_files": return .array(document.snapshot.files.map { .string($0.path) })
        case "editor_file_read":
            guard let path = arguments["path"].string, let file = document.snapshot.file(path) else { throw StudioError.invalid("Файл не найден.") }
            guard file.data.count <= 100_000 else { throw StudioError.invalid("Файл слишком велик для текстового контекста.") }
            return .string(file.text)
        case "editor_file_write":
            guard let path = arguments["path"].string, let text = arguments["content"].string else { throw StudioError.invalid("Нужны path и content.") }
            try document.write(path, data: Data(text.utf8)); changed(); return .string("Saved " + path)
        case "editor_file_delete":
            guard let path = arguments["path"].string else { throw StudioError.invalid("Нужен path.") }
            try document.delete(path); changed(); return .string("Deleted " + path)
        case "editor_scene_get": return scene?.value ?? .null
        case "editor_scene_set":
            guard var scene, let entity = arguments["entity"].string, let component = arguments["component"].string, let field = arguments["field"].string else { throw StudioError.invalid("Нужны entity, component и field.") }
            try scene.set(entity: entity, component: component, field: field, value: arguments["value"])
            try document.write(document.snapshot.scenePath, data: scene.encoded()); changed(); return .string("Scene updated")
        case "editor_scene_add":
            guard var scene else { throw StudioError.invalid("Нет сцены.") }
            let id = try scene.add(name: arguments["name"].string ?? "Object", components: arguments["components"].object, parent: arguments["parent"].string)
            try document.write(document.snapshot.scenePath, data: scene.encoded()); changed(); return .string(id)
        case "editor_build": return .object(["diagnostics": .string(validateSources())])
        case "editor_play_start": tab = .game; await play(); return .object(["running": .bool(isRunning), "error": error.map(StudioValue.string) ?? .null])
        case "editor_play_stop": stop(); return .string("Stopped")
        case "editor_play_logs": return try StudioValue.decode(await browser.perform("preview.logs"))
        case "editor_play_input": try await browser.input(arguments); return .string("Input sent")
        case "editor_play_capture":
            guard models.first(where: { $0["id"].string == modelID })?["vision"] == .bool(true) else { throw StudioError.unavailable("Выбранная модель не поддерживает изображения.") }
            return .string(try await browser.capture())
        case "editor_docs_read":
            guard let url = Bundle.module.url(forResource: "AdaScriptRecipes", withExtension: "md", subdirectory: "Resources") else { throw StudioError.unavailable("Документация недоступна.") }
            return .string(try String(contentsOf: url, encoding: .utf8))
        default: throw StudioError.invalid("Инструмент недоступен: " + name)
        }
    }

    static var agentTools: [StudioValue] {
        func tool(_ name: String, _ description: String, _ properties: [String: StudioValue] = [:], required: [String] = []) -> StudioValue {
            .object(["type": .string("function"), "function": .object(["name": .string(name), "description": .string(description),
                "parameters": .object(["type": .string("object"), "properties": .object(properties), "required": .array(required.map(StudioValue.string))])])])
        }
        let string: StudioValue = .object(["type": .string("string")])
        return [
            tool("editor_project_files", "List source and asset paths in the open AdaScript project."),
            tool("editor_file_read", "Read a project text file.", ["path": string], required: ["path"]),
            tool("editor_file_write", "Create or replace a source, scene or text asset through document undo history.", ["path": string, "content": string], required: ["path", "content"]),
            tool("editor_file_delete", "Delete a nonessential project file.", ["path": string], required: ["path"]),
            tool("editor_scene_get", "Read the authored scene, including entity IDs and component payloads."),
            tool("editor_scene_set", "Edit a component field. Transform position/rotation/scale use numeric arrays.", ["entity": string, "component": string, "field": string, "value": .object([:])], required: ["entity", "component", "field", "value"]),
            tool("editor_scene_add", "Add an entity with component payloads.", ["name": string, "components": .object(["type": .string("object")]), "parent": string], required: ["name", "components"]),
            tool("editor_build", "Validate AdaScript schemas/types and the scene before play."),
            tool("editor_play_start", "Run the game in the isolated Web Player."), tool("editor_play_stop", "Stop the running game."),
            tool("editor_play_logs", "Read game diagnostics."), tool("editor_play_capture", "Capture the game's current camera frame as a data URL."),
            tool("editor_play_input", "Send bounded keyboard/pointer input to the game.", ["key": string, "phase": string, "durationMs": .object(["type": .string("integer")])], required: ["key", "phase"]),
            tool("editor_docs_read", "Read AdaScript gameplay recipes and syntax. Read before writing gameplay code.")
        ]
    }
}
