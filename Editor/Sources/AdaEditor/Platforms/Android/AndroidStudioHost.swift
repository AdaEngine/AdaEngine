#if os(Android)
@_spi(AdaEngine) import AdaEngine
import CAndroidStudio
import Foundation

@_cdecl("ada_android_start")
public func startAndroidStudio() {
    AndroidRuntime.start {
        AndroidStudioHost.install()
        EditorComponentRegistry.registerBuiltIns()
        EditorAchievementBootstrap.install()
        EditorCloudSettingsView.installSync()
        let center = EditorNotificationCenter.shared
        center.onAction = { EditorNotificationRouter.shared.receive($0) }
        Task { await center.start() }
        return AdaEditorPhoneApp()
    }
}

/// JNI calls and callbacks are confined to Android's UI looper / Swift MainActor.
@MainActor
enum AndroidStudioHost {
    struct Reply: Codable, Sendable {
        var text: String?
        var paths: [String]?
        var insets: [Float]?
        var flag: Bool?
        var cancelled: Bool?
        var error: String?
    }

    private struct Request: Encodable {
        var text: String
        var key: String
        var secret: Bool
    }

    private static var nextRequest: Int64 = 0
    private static var callbacks: [Int64: @MainActor (Reply) -> Void] = [:]

    static func install() {
        do { try AndroidStudioCredentials.prepare() }
        catch { AndroidRuntime.log("Could not load protected credentials: \(error.localizedDescription)") }
        AndroidRuntime.didResume = refreshInsets
        AndroidRuntime.textInputFocusChanged = { focused in
            _ = try? call(focused ? "keyboard.show" : "keyboard.hide")
        }
    }

    static func call(_ action: String, text: String = "", key: String = "", secret: Bool = false, request: Int64 = 0) throws -> Reply {
        let payload = try JSONEncoder().encode(Request(text: text, key: key, secret: secret)).base64EncodedString()
        let result = action.withCString { name in
            payload.withCString { data in ada_studio_call(name, data, request) }
        }
        guard let result else { throw Failure("Android activity is unavailable.") }
        defer { ada_studio_free(result) }
        guard let data = Data(base64Encoded: String(cString: result)) else { throw Failure("Invalid Android host response.") }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        if let error = reply.error { throw Failure(error) }
        return reply
    }

    @discardableResult
    static func request(_ action: String, text: String = "", key: String = "", secret: Bool = false, completion: @escaping @MainActor (Reply) -> Void) -> Int64 {
        nextRequest &+= 1
        let id = nextRequest
        callbacks[id] = completion
        do { _ = try call(action, text: text, key: key, secret: secret, request: id) }
        catch { callbacks.removeValue(forKey: id)?(Reply(error: error.localizedDescription)) }
        return id
    }

    static func cancel(_ id: Int64) {
        callbacks.removeValue(forKey: id)
    }

    static func receive(_ reply: Reply, request: Int64) {
        if request == -1 {
            AndroidRuntime.insertText(reply.text ?? "", deleteBackward: reply.flag == true)
        } else if request == -2 {
            AndroidRuntime.setKeyboardOccludedHeight(Float(reply.text ?? "") ?? 0)
        } else if request == -3 {
            AndroidRuntime.requestBack()
        } else if request == -4 {
            if let insets = reply.insets, insets.count == 4 {
                AndroidRuntime.setSafeAreaInsets(top: insets[0], leading: insets[1], bottom: insets[2], trailing: insets[3])
            }
            AndroidRuntime.setKeyboardOccludedHeight(Float(reply.text ?? "") ?? 0)
        } else {
            callbacks.removeValue(forKey: request)?(reply)
        }
    }

    static func refreshInsets() {
        if let reply = try? call("insets") { receive(reply, request: -4) }
    }

    static func pickFiles(imagesOnly: Bool, completion: @escaping @MainActor (AssetFilePickerResult) -> Void) {
        request(imagesOnly ? "pick.images" : "pick.files") { reply in
            if let error = reply.error { completion(.unavailable(error)) }
            else if reply.cancelled == true { completion(.cancelled) }
            else { completion(.selected((reply.paths ?? []).map { URL(fileURLWithPath: $0) })) }
        }
    }

    static func authenticate(_ url: URL) async throws -> URL {
        try Task.checkCancellation()
        let timeout = Task { @MainActor in
            try await Task.sleep(for: .seconds(300))
            _ = try? call("auth.cancel")
        }
        defer { timeout.cancel() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request("authenticate", text: url.absoluteString) { reply in
                    if let value = reply.text, let callback = URL(string: value) {
                        continuation.resume(returning: callback)
                    } else {
                        continuation.resume(throwing: Failure(reply.error ?? "Sign-in cancelled or expired."))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in _ = try? call("auth.cancel") }
        }
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}

@_cdecl("ada_studio_receive")
func receiveAndroidStudioReply(_ request: Int64, _ payload: UnsafePointer<CChar>?) {
    guard let payload,
          let data = Data(base64Encoded: String(cString: payload)),
          let reply = try? JSONDecoder().decode(AndroidStudioHost.Reply.self, from: data) else { return }
    Task { @MainActor in AndroidStudioHost.receive(reply, request: request) }
}
#endif
