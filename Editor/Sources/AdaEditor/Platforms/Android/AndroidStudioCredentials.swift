#if os(Android)
import Foundation
import Synchronization

/// Reads are synchronized because the agent's synchronous token provider runs
/// off the UI actor. Keystore operations and cache mutations run on MainActor.
enum AndroidStudioCredentials {
    private static let storage = Mutex<[String: Data]>([:])

    @MainActor
    static func prepare() throws {
        for key in [
            "org.adaengine.editor.sloppy-runtime:openai-api",
            "org.adaengine.editor.codex:openai-oauth",
            "org.adaengine.editor.openai-images:default",
            "org.adaengine.cloud:session"
        ] {
            let encoded = try AndroidStudioHost.call("credential.read", key: key).text ?? ""
            if !encoded.isEmpty, let data = Data(base64Encoded: encoded) {
                storage.withLock { $0[key] = data }
            }
        }
    }

    static func load(key: String) -> Data? { storage.withLock { $0[key] } }

    @MainActor
    static func save(_ data: Data, key: String) throws {
        _ = try AndroidStudioHost.call("credential.write", text: data.base64EncodedString(), key: key)
        storage.withLock { $0[key] = data }
    }

    @MainActor
    static func delete(key: String) throws {
        _ = try AndroidStudioHost.call("credential.delete", key: key)
        storage.withLock { $0.removeValue(forKey: key) }
    }
}
#endif
