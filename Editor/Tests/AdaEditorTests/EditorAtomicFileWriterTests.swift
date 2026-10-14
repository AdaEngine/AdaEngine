import Foundation
import Testing

@testable import AdaEditor

@Suite("Atomic editor file writes", .serialized)
struct EditorAtomicFileWriterTests {
    @Test("existing files are replaced without Foundation replaceItemAt")
    func replacesExistingFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorAtomicWrite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let destination = root.appendingPathComponent("settings.json")
        try EditorAtomicFileWriter.write(Data("first".utf8), to: destination)
        try EditorAtomicFileWriter.write(Data("second".utf8), to: destination)

        #expect(try String(contentsOf: destination, encoding: .utf8) == "second")
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["settings.json"])
    }

    @Test("Unicode paths and strings survive atomic replacement")
    func replacesUnicodeFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorAtomicWrite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let destination = root.appendingPathComponent("настройки.json")
        try EditorAtomicFileWriter.write("Привет", to: destination)
        try EditorAtomicFileWriter.write("Работает", to: destination)

        #expect(try String(contentsOf: destination, encoding: .utf8) == "Работает")
    }
}
