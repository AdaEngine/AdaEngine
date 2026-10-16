import Foundation

// Test-only error boundary so these production SDK locators can be compiled and
// exercised without linking the editor, renderer or testable Release modules.
enum EditorCLIError: Error { case environment(String) }

@main
struct WindowsSDKCheck {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("Original Studio")
        for name in ["AdaEngine/Package.swift", "AdaScript/Package.swift", "AdaScript/tools/aot_build.py", "AdaScript/gravity.exe"] {
            let url = original.appendingPathComponent("BuildSDK/" + name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if name.hasSuffix("gravity.exe") {
                try FileManager.default.copyItem(at: Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]), to: url)
            } else {
                try Data().write(to: url)
            }
        }
        try Data("{\"schemaVersion\":1}".utf8).write(to: original.appendingPathComponent("BuildSDK/sdk.json"))
        let moved = root.appendingPathComponent("Moved Кириллица & Studio")
        try FileManager.default.moveItem(at: original, to: moved)
        let executable = moved.appendingPathComponent("AdaEditor.exe")
        let sdk = try EditorBuildSDK.locate(executable: executable, environment: [:])
        guard sdk.compilerRoot.path == moved.appendingPathComponent("BuildSDK/AdaScript").path,
              EditorEngineSource.locate(executable: executable, environment: [:])?.path == sdk.engineRoot.path else {
            throw EditorCLIError.environment("Installed SDK did not resolve after relocation.")
        }
        try FileManager.default.removeItem(at: sdk.engineRoot.appendingPathComponent("Package.swift"))
        guard EditorEngineSource.locate(executable: executable, environment: [:]) == nil else {
            throw EditorCLIError.environment("Invalid installed SDK fell back to the checkout.")
        }
        do {
            _ = try EditorBuildSDK.locate(executable: executable, environment: [:])
        } catch {
            print("Windows SDK relocation and missing-source checks passed.")
            return
        }
        throw EditorCLIError.environment("Incomplete installed SDK was accepted.")
    }
}
