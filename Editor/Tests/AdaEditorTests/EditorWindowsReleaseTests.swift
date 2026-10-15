#if os(Windows)
import Foundation
import Testing

@testable import AdaEditor

@Suite("Windows Studio release")
struct EditorWindowsReleaseTests {
    @Test("Installed SDK resolves beside the executable after relocation")
    func relocatedSDK() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("Studio")
        for name in ["AdaEngine/Package.swift", "AdaScript/Package.swift", "AdaScript/tools/aot_build.py", "AdaScript/gravity.exe"] {
            let url = original.appendingPathComponent("BuildSDK/" + name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if name.hasSuffix("gravity.exe") {
                try FileManager.default.copyItem(at: #require(Bundle.main.executableURL), to: url)
            } else {
                try Data().write(to: url)
            }
        }
        try Data("{\"schemaVersion\":1}".utf8).write(to: original.appendingPathComponent("BuildSDK/sdk.json"))
        let moved = root.appendingPathComponent("Moved Studio Кириллица")
        try FileManager.default.moveItem(at: original, to: moved)
        let executable = moved.appendingPathComponent("AdaEditor.exe")
        let sdk = try EditorBuildSDK.locate(executable: executable, environment: [:])
        #expect(sdk.compilerRoot.path == moved.appendingPathComponent("BuildSDK/AdaScript").path)
        #expect(EditorEngineSource.locate(executable: executable, environment: [:])?.path == sdk.engineRoot.path)
        try FileManager.default.removeItem(at: sdk.engineRoot.appendingPathComponent("Package.swift"))
        #expect(EditorEngineSource.locate(executable: executable, environment: [:]) == nil)
        #expect(throws: EditorCLIError.self) { try EditorBuildSDK.locate(executable: executable, environment: [:]) }
    }
}
#endif
