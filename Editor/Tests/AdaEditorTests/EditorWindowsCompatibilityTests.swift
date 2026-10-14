import AdaScriptCompilerCore
@_spi(Internal) @testable import AdaPlatform
import Foundation
import Gravity
import Testing
@testable import AdaScripting

@testable import AdaEditor

@Suite("Editor Windows compatibility")
struct EditorWindowsCompatibilityTests {
    @Test("Windows run destination survives saving and reopening a project")
    @MainActor
    func savesWindowsDestination() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var project = try ProjectSystem.loadProject(from: Data(#"{"schemaVersion":3,"buildSystem":"swiftpm","paths":{}}"#.utf8))
        project.run.destination = .windows
        try ProjectSystem.saveProject(project, at: directory)
        #expect(try ProjectSystem.loadProject(at: directory).run.destination == .windows)
        #expect(EditorViewModel.editorRunDestination(from: .windows) == .windows)
        #expect(EditorRunDestination.windows.adaProjectDestination == .windows)
    }

    @Test("Scene validation distinguishes JSON booleans from zero and one")
    func distinguishesJSONBooleans() throws {
        let schema = AdaScriptDataSchema(
            fields: [.init(defaultValue: .bool(false), name: "enabled"), .init(defaultValue: .int(0), name: "count")],
            id: "game.state", kind: .component, name: "State", sourcePath: "State.ada"
        )
        let valid = try #require(JSONSerialization.jsonObject(with: Data(#"{"enabled":true,"count":1}"#.utf8)) as? [String: Any])
        #expect(AdaScriptSceneSchemaResolver.diagnose(key: schema.id, fields: valid, schemas: [schema]).isEmpty)
        let invalid = try #require(JSONSerialization.jsonObject(with: Data(#"{"enabled":1,"count":true}"#.utf8)) as? [String: Any])
        let errors = AdaScriptSceneSchemaResolver.diagnose(key: schema.id, fields: invalid, schemas: [schema])
        #expect(errors.filter { $0.severity == .error }.count == 2)
    }

    #if os(Windows)
    @Test("Windows drive and UNC paths resolve to real project files")
    @MainActor
    func recognizesAbsoluteWindowsPaths() {
        for path in ["D:/Projects/Game/Сцена.ascn", "C:\\Projects\\Game\\Main.ada", "\\\\server\\share\\Texture.png"] {
            #expect(EditorViewModel.absoluteFilePath(from: path) == path)
        }
        for path in ["Assets/Scenes/Main.ascn", "D:relative.ada", "https://example.com/file", ""] {
            #expect(EditorViewModel.absoluteFilePath(from: path) == nil)
        }
    }

    @Test("Windows project scenes load from disk and save authored changes")
    @MainActor
    func savesRealWindowsScene() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let assets = directory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Windows"), at: directory)
        let url = assets.appendingPathComponent("Сцена.ascn")
        let original = SceneDocumentFormat.defaultSceneYAML(projectName: "From disk")
        try original.write(to: url, atomically: true, encoding: .utf8)
        let model = EditorViewModel(project: .init(name: "Windows", path: directory.path))
        let item = try #require(model.projectSidebar.items.first { $0.relativePath == "Assets/Сцена.ascn" })
        model.openProjectItem(item)
        #expect(model.workbench.activeSceneDocument?.absolutePath == url.path)
        #expect(model.workbench.activeSceneDocument?.content == original)
        let document = try #require(model.workbench.activeSceneDocument)
        model.workbench.addEntity(to: document.id)
        #expect(model.workbench.saveActiveDocument())
        let saved = try String(contentsOf: url, encoding: .utf8)
        #expect(saved != original)
        #expect(model.workbench.activeSceneDocument?.isDirty == false)
        #expect(model.workbench.activeSceneDocument?.lastSavedContent == saved)
        // Keep the existing conflict protection when another program edits the file.
        try original.write(to: url, atomically: true, encoding: .utf8)
        model.workbench.addEntity(to: document.id)
        #expect(!model.workbench.saveActiveDocument())
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @Test("Native Windows strings retain Cyrillic and surrogate pairs")
    func nativeUnicodeStrings() {
        #expect("Сцена 🌈".wide == Array("Сцена 🌈".utf16) + [0])
    }

    @Test("Windows monitor identity survives discovery", .enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_VALIDATE_WINDOWS_SCREEN"] == "1"))
    func retainsWindowsMonitor() throws {
        let manager = WindowsScreenManager()
        let screen = try #require(manager.getMainScreen())
        withExtendedLifetime(manager) {
            #expect(screen.systemScreen != nil)
            #expect(screen.scale > 0)
            #expect(screen.size.width > 0 && screen.size.height > 0)
        }
    }

    @Test("Windows modifier snapshots support Ctrl shortcuts and selection modifiers")
    func mapsWindowsKeyboardModifiers() {
        #expect(WindowsKeyboardModifiers.make(shift: 0, control: 0, alt: 0, capsLock: 0).isEmpty)
        let modifiers = WindowsKeyboardModifiers.make(shift: .min, control: .min, alt: .min, capsLock: 1)
        #expect(modifiers == [.shift, .control, .alt, .capsLock])
        #expect(WindowsKeyboardModifiers.make(shift: 0, control: 0, alt: 0, capsLock: 0, superKey: .min).contains(.main))
    }

    @Test("Windows AdaScript strings keep UTF-8 bytes and can be released repeatedly")
    func releasesScriptStrings() {
        AdaScriptRuntimeCoordinator.lock.lock()
        defer { AdaScriptRuntimeCoordinator.lock.unlock() }
        for _ in 0..<20 {
            let module = ResolvedGravityScriptModule(
                entrySource: "", sourcesByPath: [:], pathsByFileID: [:], nonSendableTypeNames: [], asyncDeclarations: [], importDiagnostics: []
            )
            let delegate = AnnotatedGravityRuntimeDelegate(module: module)
            let vm = GravityVirtualMachine(settings: .init(), delegate: delegate)
            let value = GSValue(string: "Цвет 🌈", in: vm)
            #expect(value.toString == "Цвет 🌈")
        }
    }

    @Test("Streaming saves replace existing Windows files and cancellation retains them")
    func commitsStreamingSave() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("Сохранение.txt")
        try Data("old".utf8).write(to: destination)
        let writer = AdaScriptSaveWriter.make(path: destination.path, url: destination, errorCode: nil, onWake: nil)
        #expect(try await completed(writer.append("новое 🌈")).isSuccess())
        #expect(try await completed(writer.finish()).committed())
        #expect(try String(contentsOf: destination, encoding: .utf8) == "новое 🌈")
        let cancelled = AdaScriptSaveWriter.make(path: destination.path, url: destination, errorCode: nil, onWake: nil)
        #expect(try await completed(cancelled.append("discard")).isSuccess())
        cancelled.cancel()
        #expect(cancelled.append("late").result().errorCode() == "cancelled")
        #expect(try String(contentsOf: destination, encoding: .utf8) == "новое 🌈")
    }

    private func completed(_ operation: AdaScriptAsyncOperation) async throws -> AdaScriptAsyncResult {
        for _ in 0..<200 {
            if operation.isDone() { return operation.result() }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw EditorWebToolError("Save operation did not complete")
    }


    @Test("Native color selection preserves RGB ordering and alpha")
    @MainActor
    func nativeColorConversion() {
        let value = EditorInspectorColorValue(red: 1, green: 0.5, blue: 0, alpha: 0.25)
        let reference = EditorPlatformColorPicker.colorReference(value)
        #expect(reference == 0x0080FF)
        let selected = EditorPlatformColorPicker.colorValue(reference, alpha: value.alpha)
        #expect(selected.red == 1 && selected.blue == 0)
        #expect(selected.green == Float(128) / 255)
        #expect(selected.alpha == 0.25)
    }

    @Test("Windows toolbar offers local Windows execution")
    func offersWindowsExecution() {
        #expect(EditorRunDestination.toolbarDestinations == [.windows])
    }

    @Test("Windows file dialog paths preserve Unicode and multiple selection")
    @MainActor
    func decodesWindowsFileSelection() {
        let single = Array("D:\\Projects\\My Game\\Сцена.ascn\0\0".utf16)
        #expect(WindowsProjectFilePicker.urls(from: single).map(\.path) == ["D:/Projects/My Game/Сцена.ascn"])
        let multiple = Array("D:\\Projects\\My Game\0Сцена.ascn\0Texture.png\0\0".utf16)
        #expect(WindowsProjectFilePicker.urls(from: multiple).map(\.path) == ["D:/Projects/My Game/Сцена.ascn", "D:/Projects/My Game/Texture.png"])
    }
    #endif
}
