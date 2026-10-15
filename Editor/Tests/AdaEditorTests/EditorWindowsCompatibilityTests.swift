import AdaInput
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
    @Test("Windows punctuation keys reach desktop shortcuts, including Ctrl-comma Settings")
    @MainActor
    func translatesNativePunctuation() {
        let mappings: [(UInt16, KeyCode)] = [
            (0xBA, .semicolon), (0xBB, .equals), (0xBC, .comma), (0xBD, .minus), (0xBE, .period),
            (0xBF, .slash), (0xC0, .backquote), (0xDB, .leftBracket), (0xDC, .backslash),
            (0xDD, .rightBracket), (0xDE, .quote), (0x2D, .insert),
        ]
        for (native, key) in mappings {
            #expect(WindowsKeyboard.shared.translateKey(from: native) == key)
            #expect(WindowsKeyboard.shared.osKeyCode(from: key) == native)
        }
    }

    @Test("Browser launches forward only matching, live Cloud callbacks")
    @MainActor
    func forwardsCloudCallback() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = String(repeating: "c", count: 43)
        let code = String(repeating: "d", count: 43)
        let arguments = ["AdaEditor.exe", "--cloud-callback=adaeditor://cloud/callback?state=\(state)&code=\(code)"]
        let pending = directory.appendingPathComponent(state + ".pending")
        let callback = directory.appendingPathComponent(state + ".callback")
        #expect(try EditorWindowsCloudAuthentication.receiveLaunchCallback(arguments, callbackDirectory: directory))
        #expect(!FileManager.default.fileExists(atPath: callback.path))
        try Data().write(to: pending)
        #expect(try EditorWindowsCloudAuthentication.receiveLaunchCallback(arguments, callbackDirectory: directory))
        let url = try #require(URL(string: String(contentsOf: callback, encoding: .utf8)))
        #expect(try EditorCloudAccount.exchangeCode(from: url, expectedState: state) == code)
        try FileManager.default.removeItem(at: callback)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-301)], ofItemAtPath: pending.path)
        #expect(try EditorWindowsCloudAuthentication.receiveLaunchCallback(arguments, callbackDirectory: directory))
        #expect(!FileManager.default.fileExists(atPath: callback.path))
        #expect(try !EditorWindowsCloudAuthentication.receiveLaunchCallback(["AdaEditor.exe"], callbackDirectory: directory))
    }

    @Test("Windows host tooling finds the case-insensitive native Path variable")
    func findsHostExecutables() {
        #expect(EditorHostTools.environmentValue("PATH", in: ["Path": "C:\\Tools"]) == "C:\\Tools")
        #expect(EditorHostTools.isAbsolutePath(EditorHostTools.executable("clang")))
        #expect(EditorHostTools.isAbsolutePath(EditorHostTools.executable("python3", windowsName: "python.exe")))
    }

    @Test("Windows command runner resolves installed bare executable names")
    func runsNativePathCommand() async {
        let command = EditorProcessCommand(executablePath: "git", arguments: ["--version"],
            workingDirectory: FileManager.default.temporaryDirectory)
        let result = await EditorProcessRunner().run(command)
        #expect(result.succeeded)
        #expect(result.standardOutput.hasPrefix("git version"))
    }

    @Test("Windows launcher initializes Git using the native Path variable")
    @MainActor
    func createsGitRepositoryFromLauncher() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = ProjectOpeningViewModel(store: EditorProjectStore(
            storageURL: directory.appendingPathComponent("projects.json"), distribution: .standalone
        ))
        model.projectName = "Git Project"
        model.projectLocation = directory.path
        model.shouldCreateGitRepository = true
        model.createProject()

        let project = try #require(model.selectedProject)
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(".git/HEAD").path))
        #expect(!model.statusMessage.contains("Git was not found"))
    }

    @Test("Native Windows pointer flags preserve right and middle drags")
    func mapsNativePointerButtons() {
        #expect(WindowsPointerButtons.button(for: 0) == .none)
        #expect(WindowsPointerButtons.button(for: 1) == .left)
        #expect(WindowsPointerButtons.button(for: 2) == .right)
        #expect(WindowsPointerButtons.button(for: 16) == .middle)
        #expect(WindowsPointerButtons.button(for: 2 | 8) == .right)
    }

    @Test("Windows provides contextual system cursor resources")
    func mapsSystemCursors() {
        #expect(WindowsCursorResources.identifier(for: .iBeam) == 32513)
        #expect(WindowsCursorResources.identifier(for: .move) == 32646)
        #expect(WindowsCursorResources.identifier(for: .resizeLeftRight) == 32644)
        #expect(WindowsCursorResources.identifier(for: .resizeUpDown) == 32645)
        #expect(WindowsCursorResources.identifier(for: .forbidden) == 32648)
    }

    @Test("Cloud credentials survive reload in Windows Credential Manager")
    @MainActor
    func savesProtectedCloudCredentials() throws {
        let target = "org.adaengine.cloud/tests/" + UUID().uuidString
        defer { EditorWindowsCloudCredentials.delete(target: target) }
        #expect(try EditorWindowsCloudCredentials.read(target: target) == nil)
        let first = Data("private test session · кириллица".utf8)
        try EditorWindowsCloudCredentials.write(first, target: target)
        #expect(try EditorWindowsCloudCredentials.read(target: target) == first)
        let updated = Data("updated private test session".utf8)
        try EditorWindowsCloudCredentials.write(updated, target: target)
        #expect(try EditorWindowsCloudCredentials.read(target: target) == updated)
        EditorWindowsCloudCredentials.delete(target: target)
        #expect(try EditorWindowsCloudCredentials.read(target: target) == nil)
    }

    @Test("WSL build commands preserve paths and pass arguments without a shell")
    func mapsWSLBuildPaths() {
        #expect(EditorWindowsBuildWorker.linuxPath("D:\\Projects\\Моя игра") == "/mnt/d/Projects/Моя игра")
        let project = URL(fileURLWithPath: "D:/Projects/Моя игра")
        let command = EditorWindowsBuildWorker.webCommand(
            package: project, output: project.appendingPathComponent("Exports/Web"), product: "Game",
            engineRoot: URL(fileURLWithPath: "D:/Development/AdaEngine"), gravityRoot: nil,
            swift: "", sdk: "swift-6.3.2-RELEASE_wasm", configuration: "debug", serve: false)
        #expect(command.arguments.contains("--exec"))
        #expect(!command.arguments.contains("-c"))
        #expect(command.arguments.contains("/mnt/d/Projects/Моя игра"))
        #expect(command.arguments.contains("swift-6.3.2-RELEASE_wasm"))
    }

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
        #expect(EditorRunDestination.toolbarDestinations == [.windows, .web, .android, .player])
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
