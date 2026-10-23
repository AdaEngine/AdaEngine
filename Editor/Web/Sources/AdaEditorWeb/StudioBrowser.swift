import AdaStudioCore
import Foundation
#if os(WASI)
import JavaScriptKit
#endif

/// The browser API boundary. Project operations and UI stay in Swift/AdaUI.
@MainActor final class StudioBrowser: StudioCloudTransport, StudioRecoveryStorage, StudioFileAccess, StudioPreview {
    private(set) var logs: [String] = []
    var editMode = false
    #if os(WASI)
    private var callbacks: [String: JSClosure] = [:]
    #endif

    func perform(_ method: String, _ arguments: StudioValue = .null, onEvent: (@MainActor (StudioValue) -> Void)? = nil) async throws -> Data {
        #if os(WASI)
        guard let bridge = JSObject.global["adaStudio"].object else { throw StudioError.unavailable("Не загружен браузерный модуль Studio.") }
        let id = UUID().uuidString
        let json = String(decoding: try arguments.encoded(), as: UTF8.self)
        return try await withCheckedThrowingContinuation { continuation in
            let callback = JSClosure { [weak self] values in
                let text = values.first?.string ?? "{}"
                Task { @MainActor in
                    guard let self else { return }
                    do {
                        let result = try StudioValue.decode(Data(text.utf8))
                        if result["kind"].string == "event" { onEvent?(result["value"]); return }
                        self.callbacks[id] = nil
                        if result["kind"].string == "error" {
                            if result["status"].number == 401 { continuation.resume(throwing: StudioError.authenticationRequired) }
                            else if result["status"].number == 409, arguments["path"].string?.hasPrefix("/v1/workspaces") == true { continuation.resume(throwing: StudioError.conflict) }
                            else { continuation.resume(throwing: StudioError.unavailable(result["message"].string ?? "Ошибка браузера.")) }
                        } else { continuation.resume(returning: try result["value"].encoded()) }
                    } catch { self.callbacks[id] = nil; continuation.resume(throwing: error) }
                }
                return .undefined
            }
            callbacks[id] = callback
            _ = bridge.call?(method, json, callback)
        }
        #else
        throw StudioError.unavailable("Откройте Ada Studio Web в браузере.")
        #endif
    }

    func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        try await perform("request", .object(["path": .string(path), "method": .string(method), "body": try body.map(StudioValue.decode) ?? .null]))
    }
    func stream(path: String, body: Data, onEvent: @escaping @MainActor (StudioValue) -> Void) async throws {
        _ = try await perform("stream", .object(["path": .string(path), "body": try StudioValue.decode(body)]), onEvent: onEvent)
    }
    func cancelRequests() { fire("cancel") }
    func fire(_ method: String, _ value: StudioValue = .null) {
        #if os(WASI)
        guard let text = try? String(decoding: value.encoded(), as: UTF8.self) else { return }
        _ = JSObject.global["adaStudio"].object?.fire?(method, text)
        #endif
    }
    func load(account: String, project: String) async throws -> Data? {
        let result = try await perform("recovery.load", .object(["account": .string(account), "project": .string(project)]))
        return result == Data("null".utf8) ? nil : result
    }
    func save(account: String, project: String, data: Data) async throws {
        _ = try await perform("recovery.save", .object(["account": .string(account), "project": .string(project), "value": try StudioValue.decode(data)]))
    }
    func remove(account: String, project: String) async throws {
        _ = try await perform("recovery.remove", .object(["account": .string(account), "project": .string(project)]))
    }
    func open(accept: String) async throws -> StudioFile? {
        let result = try await perform("file.open", .object(["accept": .string(accept)]))
        return try JSONDecoder().decode(StudioFile?.self, from: result)
    }
    func download(name: String, data: Data) throws {
        fire("file.download", .object(["name": .string(name), "data": .string(data.base64EncodedString())]))
    }
    func load(_ snapshot: StudioSnapshot) async throws {
        logs = []
        var preview = snapshot
        preview.files = try snapshot.exportFiles()
        preview.messages = []
        var payload = try StudioValue.decode(JSONEncoder().encode(preview))
        payload["editMode"] = .bool(editMode)
        _ = try await perform("preview.load", payload) { [weak self] event in
            if let log = event["message"].string { self?.logs.append(log) }
        }
    }
    func stop() { fire("preview.stop") }
    func capture() async throws -> String {
        let result = try StudioValue.decode(await perform("preview.capture"))
        guard let image = result.string else { throw StudioError.unavailable("Кадр игры недоступен.") }
        return image
    }
    func input(_ event: StudioValue) async throws { _ = try await perform("preview.input", event) }
    func previewBounds(x: Float, y: Float, width: Float, height: Float, visible: Bool) {
        fire("preview.bounds", .object(["x": .double(Double(x)), "y": .double(Double(y)), "width": .double(Double(width)), "height": .double(Double(height)), "visible": .bool(visible)]))
    }
}
