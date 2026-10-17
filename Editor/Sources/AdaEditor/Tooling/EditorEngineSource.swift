import Foundation

/// Resolves sources on the current machine. Release apps never use their build machine's source location.
enum EditorEngineSource {
    static func locate(
        executable: URL? = Bundle.main.executableURL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let root: URL
        if let path = environment["ADAENGINE_PACKAGE_PATH"], !path.isEmpty {
            root = URL(fileURLWithPath: path)
        } else if let sdk = environment["ADA_STUDIO_SDK"], !sdk.isEmpty {
            root = URL(fileURLWithPath: sdk).appendingPathComponent("AdaEngine")
        } else {
            #if os(macOS)
            if let executable, let app = EditorBuildSDK.appBundle(containing: executable) {
                root = app.appendingPathComponent("Contents/Resources/BuildSDK/AdaEngine")
            } else {
                #if DEBUG
                root = developmentRoot
                #else
                return nil
                #endif
            }
            #elseif os(Windows) || os(Linux)
            if let executable,
               FileManager.default.fileExists(atPath: executable.deletingLastPathComponent().appendingPathComponent("BuildSDK").path) {
                root = executable.deletingLastPathComponent().appendingPathComponent("BuildSDK/AdaEngine")
            } else {
                #if DEBUG
                root = developmentRoot
                #else
                return nil
                #endif
            }
            #else
            #if DEBUG
            root = developmentRoot
            #else
            return nil
            #endif
            #endif
        }
        let standardized = root.standardizedFileURL
        return FileManager.default.fileExists(atPath: standardized.appendingPathComponent("Package.swift").path)
            ? standardized : nil
    }

    #if DEBUG
    private static var developmentRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
    #endif
}
