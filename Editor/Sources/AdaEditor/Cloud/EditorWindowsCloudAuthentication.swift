#if os(Windows)
import AdaEngine
import Foundation
import WinSDK

/// Browser callbacks carry a one-time PKCE code, never an access token. Windows
/// launches a short-lived instance which forwards that callback to the waiting
/// instance through the user's private application-data directory.
@MainActor
enum EditorWindowsCloudAuthentication {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AdaStudio/CloudCallbacks", isDirectory: true)
    }

    static func receiveLaunchCallback(_ arguments: [String], callbackDirectory: URL? = nil) throws -> Bool {
        let directory = callbackDirectory ?? Self.directory
        guard let argument = arguments.first(where: { $0.hasPrefix("--cloud-callback=") }) else { return false }
        guard let url = URL(string: String(argument.dropFirst("--cloud-callback=".count))),
              let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "state" })?.value,
              state.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else {
            throw EditorCloudAccount.CloudError.message("Invalid Cloud callback.")
        }
        _ = try EditorCloudAccount.exchangeCode(from: url, expectedState: state)
        // Only forward to a pending request made by the original instance.
        let pending = directory.appendingPathComponent(state + ".pending")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: pending.path),
              let created = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(created) < 300 else { return true }
        try Data(url.absoluteString.utf8).write(to: directory.appendingPathComponent(state + ".callback"), options: .atomic)
        return true
    }

    static func authenticate(url: URL, state: String) async throws -> URL {
        try registerCallbackHandler()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pending = directory.appendingPathComponent(state + ".pending")
        let callback = directory.appendingPathComponent(state + ".callback")
        try Data().write(to: pending, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: pending)
            try? FileManager.default.removeItem(at: callback)
        }
        guard Application.shared.openURL(url) else {
            throw EditorCloudAccount.CloudError.message("Could not open the sign-in browser.")
        }
        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline {
            try Task.checkCancellation()
            if let data = try? Data(contentsOf: callback), data.count < 8192,
               let address = String(data: data, encoding: .utf8), let result = URL(string: address) {
                _ = try EditorCloudAccount.exchangeCode(from: result, expectedState: state)
                return result
            }
            try await Task.sleep(for: .milliseconds(150))
        }
        throw EditorCloudAccount.CloudError.message("Browser sign-in timed out. Please try again.")
    }

    private static func registerCallbackHandler() throws {
        guard let executable = Bundle.main.executableURL else {
            throw EditorCloudAccount.CloudError.message("Cannot locate Studio's browser callback handler.")
        }
        try setRegistryValue(path: "Software\\Classes\\adaeditor", name: nil, value: "URL:Ada Studio")
        try setRegistryValue(path: "Software\\Classes\\adaeditor", name: "URL Protocol", value: "")
        let windowsPath = executable.path.replacingOccurrences(of: "/", with: "\\")
        try setRegistryValue(path: "Software\\Classes\\adaeditor\\shell\\open\\command", name: nil,
                             value: "\"" + windowsPath + "\" \"--cloud-callback=%1\"")
    }

    private static func setRegistryValue(path: String, name: String?, value: String) throws {
        var handle: HKEY?
        let result = path.withCString(encodedAs: UTF16.self) { pointer in
            RegCreateKeyExW(HKEY_CURRENT_USER, pointer, 0, nil, 0, DWORD(KEY_SET_VALUE), nil, &handle, nil)
        }
        guard result == ERROR_SUCCESS, let handle else {
            throw EditorCloudAccount.CloudError.message("Cannot register browser callback (\(result)).")
        }
        defer { RegCloseKey(handle) }
        let bytes = Array(value.utf16) + [0]
        let write: LSTATUS = bytes.withUnsafeBytes { buffer in
            if let name {
                return name.withCString(encodedAs: UTF16.self) {
                    RegSetValueExW(handle, $0, 0, DWORD(REG_SZ), buffer.bindMemory(to: BYTE.self).baseAddress, DWORD(buffer.count))
                }
            }
            return RegSetValueExW(handle, nil, 0, DWORD(REG_SZ), buffer.bindMemory(to: BYTE.self).baseAddress, DWORD(buffer.count))
        }
        guard write == ERROR_SUCCESS else {
            throw EditorCloudAccount.CloudError.message("Cannot register browser callback (\(write)).")
        }
    }
}

/// Generic credentials are scoped to the signed-in Windows user and persisted
/// by Credential Manager, rather than stored as plain JSON in preferences.
enum EditorWindowsCloudCredentials {
    private static let sessionTarget = "org.adaengine.cloud/session"
    static func read(target: String = sessionTarget) throws -> Data? {
        var credential: PCREDENTIALW?
        let found = target.withCString(encodedAs: UTF16.self) { CredReadW($0, DWORD(CRED_TYPE_GENERIC), 0, &credential) }
        guard found, let credential else {
            if GetLastError() == ERROR_NOT_FOUND { return nil }
            throw EditorCloudAccount.CloudError.message("Windows credential storage is unavailable.")
        }
        defer { CredFree(credential) }
        guard let blob = credential.pointee.CredentialBlob else { return nil }
        return Data(bytes: blob, count: Int(credential.pointee.CredentialBlobSize))
    }

    static func write(_ data: Data, target: String = sessionTarget) throws {
        guard data.count <= Int(CRED_MAX_CREDENTIAL_BLOB_SIZE) else {
            throw EditorCloudAccount.CloudError.message("Cloud session exceeds the Windows credential limit.")
        }
        let saved = target.withCString(encodedAs: UTF16.self) { name in
            data.withUnsafeBytes { bytes in
                var credential = CREDENTIALW()
                credential.Type = DWORD(CRED_TYPE_GENERIC)
                credential.TargetName = UnsafeMutablePointer(mutating: name)
                credential.Persist = DWORD(CRED_PERSIST_LOCAL_MACHINE)
                credential.CredentialBlobSize = DWORD(bytes.count)
                credential.CredentialBlob = UnsafeMutablePointer(mutating: bytes.bindMemory(to: BYTE.self).baseAddress)
                return CredWriteW(&credential, 0)
            }
        }
        guard saved else { throw EditorCloudAccount.CloudError.message("Could not save the Cloud session in Windows Credential Manager.") }
    }

    static func delete(target: String = sessionTarget) {
        _ = target.withCString(encodedAs: UTF16.self) { CredDeleteW($0, DWORD(CRED_TYPE_GENERIC), 0) }
    }
}
#endif
