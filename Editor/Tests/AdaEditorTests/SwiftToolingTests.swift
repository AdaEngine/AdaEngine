@testable import AdaEditor
import AdaPackageManifestTool
import Foundation
import Testing

@Suite("SwiftPM workspace tooling")
struct SwiftToolingTests {
    @Test("SwiftPM service constructs expected commands")
    func swiftPMCommandConstruction() {
        let service = SwiftPMWorkspaceService(processRunner: FakeProcessRunner(results: []))
        let toolchain = SwiftToolchain(swiftExecutablePath: "/usr/bin/swift", sourceKitLSPExecutablePath: "/usr/bin/sourcekit-lsp")
        let projectURL = URL(fileURLWithPath: "/tmp/Game", isDirectory: true)

        #expect(service.makeCommand(.resolve, projectURL: projectURL, toolchain: toolchain).arguments == ["package", "resolve"])
        #expect(service.makeCommand(.describe, projectURL: projectURL, toolchain: toolchain).arguments == ["package", "describe", "--type", "json"])
        #expect(service.makeCommand(.build(target: "Game", buildTests: false), projectURL: projectURL, toolchain: toolchain).arguments == ["build", "--target", "Game"])
        #expect(service.makeCommand(.build(target: nil, buildTests: true), projectURL: projectURL, toolchain: toolchain).arguments == ["build", "--build-tests"])
        #expect(service.makeCommand(.run(target: "Game", arguments: ["--debug"]), projectURL: projectURL, toolchain: toolchain).arguments == ["run", "Game", "--", "--debug"])
        #expect(service.makeCommand(.test(filter: "GameTests"), projectURL: projectURL, toolchain: toolchain).arguments == ["test", "--parallel", "--filter", "GameTests"])
    }

    @Test("package describe JSON parses products targets dependencies and plugins")
    func packageDescriptionParses() throws {
        let model = try #require(SwiftPackageModel.parse(from: packageDescriptionJSON))

        #expect(model.name == "Game")
        #expect(model.executableTargets == ["Game"])
        #expect(model.testTargets == ["GameTests"])
        #expect(model.pluginTargets == ["GamePlugin"])
        #expect(model.dependencies.map(\.identity) == ["adaengine"])
    }

    @Test("preview scanner finds top-level previewable views")
    func previewScannerFindsDeclarations() {
        let declarations = EditorPreviewScanner.declarations(in: """
        import AdaEngine

        @Previewable(title: "Primary")
        public struct PrimaryView: View {
            var body: some View { EmptyView() }
        }

        @Previewable
        struct SecondaryView: View {
            var body: some View { EmptyView() }
        }

        @AdaUI.Previewable(title: "Private")
        private final class PrivatePreviewView: AdaUI.View {
            var body: some View { EmptyView() }
        }

        @Previewable
        struct NotAView {
        }
        """)

        #expect(declarations.map(\.typeName) == ["PrimaryView", "SecondaryView", "PrivatePreviewView"])
        #expect(declarations.map(\.title) == ["Primary", "SecondaryView", "Private"])
        #expect(declarations.map(\.symbolName) == [
            "ada_editor_preview_make_PrimaryView",
            "ada_editor_preview_make_SecondaryView",
            "ada_editor_preview_make_PrivatePreviewView"
        ])
    }

    @Test("preview builder mirrors executable preview from entrypoint file")
    func previewBuilderMirrorsExecutableTarget() async throws {
        let fileManager = FileManager.default
        let projectURL = fileManager.temporaryDirectory
            .appendingPathComponent("AdaEditorPreviewBuilder-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: projectURL)
        }

        let gameSourceURL = projectURL.appendingPathComponent("Sources/Game", isDirectory: true)
        let sharedSourceURL = projectURL.appendingPathComponent("Sources/Shared", isDirectory: true)
        try fileManager.createDirectory(at: gameSourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sharedSourceURL, withIntermediateDirectories: true)
        try """
        import AdaEngine

        @main
        struct GameMain {
            static func main() {}
        }

        @Previewable
        struct GameView: View {
            var body: some View { EmptyView() }
        }
        """.write(to: gameSourceURL.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        try "struct SharedHelper {}\n".write(to: sharedSourceURL.appendingPathComponent("SharedHelper.swift"), atomically: true, encoding: .utf8)

        let model = SwiftPackageModel(
            name: "Game",
            products: [
                SwiftPackageProduct(name: "Game", type: "executable", targets: ["Game"])
            ],
            targets: [
                SwiftPackageTarget(
                    name: "Game",
                    type: "executable",
                    path: "Sources/Game",
                    sources: ["main.swift"],
                    targetDependencies: ["Shared"],
                    productDependencies: ["AdaEngine"]
                ),
                SwiftPackageTarget(
                    name: "Shared",
                    type: "regular",
                    path: "Sources/Shared",
                    sources: ["SharedHelper.swift"],
                    targetDependencies: [],
                    productDependencies: ["Collections"]
                )
            ],
            dependencies: [
                SwiftPackageDependency(identity: "adaengine", type: "fileSystem", url: nil, path: "../AdaEngine", requirement: nil),
                SwiftPackageDependency(
                    identity: "swift-collections",
                    type: "sourceControl",
                    url: "https://github.com/apple/swift-collections.git",
                    path: nil,
                    requirement: "from: 1.2.0"
                )
            ]
        )
        let document = EditorTextDocument(
            id: "GameView.swift",
            title: "main.swift",
            relativePath: "Sources/Game/main.swift",
            absolutePath: gameSourceURL.appendingPathComponent("main.swift").path,
            language: .swift,
            content: "",
            errorMessage: nil
        )
        let declaration = EditorPreviewDeclaration(id: "GameView", title: "GameView", typeName: "GameView", line: 3)
        let runner = FakeProcessRunner(results: []) { command in
            let fileManager = FileManager.default
            let scratchPathIndex = command.arguments.firstIndex(of: "--scratch-path")
            let scratchPath = scratchPathIndex.flatMap { index -> String? in
                let valueIndex = command.arguments.index(after: index)
                guard command.arguments.indices.contains(valueIndex) else {
                    return nil
                }
                return command.arguments[valueIndex]
            }
            let buildRoot = scratchPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? command.workingDirectory.appendingPathComponent(".build", isDirectory: true)
            let buildDirectory = buildRoot.appendingPathComponent("debug", isDirectory: true)
            try? fileManager.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
            try? Data().write(to: buildDirectory.appendingPathComponent("libAdaEditorPreviewBundle.dylib"))
        }
        let previewPackageName = previewDirectoryName(relativePath: document.relativePath, declarationID: declaration.id)
        let previewPackageRoot = projectURL
            .appendingPathComponent(".build/adaeditor-previews", isDirectory: true)
            .appendingPathComponent(previewPackageName, isDirectory: true)
        let retainedBuildMarker = previewPackageRoot
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("retained-artifact.txt")
        try fileManager.createDirectory(at: retainedBuildMarker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "keep".write(to: retainedBuildMarker, atomically: true, encoding: .utf8)
        try fileManager.createDirectory(at: previewPackageRoot.appendingPathComponent("Sources/Game", isDirectory: true), withIntermediateDirectories: true)
        try "stale".write(to: previewPackageRoot.appendingPathComponent("Sources/Game/Stale.swift"), atomically: true, encoding: .utf8)

        let artifact = try await EditorPreviewBuilder(processRunner: runner).build(
            EditorPreviewBuildRequest(
                projectURL: projectURL,
                document: document,
                packageModel: model,
                declaration: declaration
            ),
            toolchain: SwiftToolchain(swiftExecutablePath: "/usr/bin/swift", sourceKitLSPExecutablePath: nil)
        )

        let previewRoot = projectURL.appendingPathComponent(".build/adaeditor-previews", isDirectory: true)
        let previewPackageURL = try #require(findFirstFile(named: "Package.swift", under: previewRoot, fileManager: fileManager))
        let manifest = try String(contentsOf: previewPackageURL, encoding: .utf8)
        let scratchRoot = previewPackageURL.deletingLastPathComponent()
        let commands = await runner.commands

        #expect(artifact.symbolName == "ada_editor_preview_make_GameView")
        #expect(artifact.libraryURL.lastPathComponent == "libAdaEditorPreviewBundle.dylib")
        #expect(artifact.libraryURL.path.contains("/.build/build-"))
        #expect(commands.first?.arguments.contains("--scratch-path") == true)
        #expect(manifest.contains(#".library(name: "AdaEditorPreviewBundle", type: .dynamic, targets: ["Game"])"#))
        #expect(manifest.contains(#".package(name: "AdaEngine", path: "\#(adaEnginePackageURL().path)")"#))
        #expect(manifest.contains(#".package(name: "swift-collections", url: "https://github.com/apple/swift-collections.git", from: "1.2.0")"#))
        #expect(manifest.contains(#"name: "Game""#))
        #expect(manifest.contains(#"dependencies: ["Shared", .product(name: "AdaEngine", package: "AdaEngine")]"#))
        #expect(manifest.contains(#"dependencies: [.product(name: "Collections", package: "swift-collections")]"#))
        #expect(!fileManager.fileExists(atPath: scratchRoot.appendingPathComponent("Sources/Game/main.swift").path))
        #expect(!fileManager.fileExists(atPath: scratchRoot.appendingPathComponent("Sources/Game/Stale.swift").path))
        #expect(fileManager.fileExists(atPath: retainedBuildMarker.path))
        let copiedMain = try String(contentsOf: scratchRoot.appendingPathComponent("Sources/Game/AdaEditorPreviewMain.swift"), encoding: .utf8)
        #expect(!copiedMain.contains("@main"))
        #expect(copiedMain.contains("@Previewable"))
        #expect(fileManager.fileExists(atPath: scratchRoot.appendingPathComponent("Sources/Shared/SharedHelper.swift").path))
    }

    @Test("build output parser extracts diagnostics")
    func buildDiagnosticsParse() {
        let projectURL = URL(fileURLWithPath: "/tmp/Game", isDirectory: true)
        let diagnostics = EditorDiagnostic.parseBuildOutput("/tmp/Game/Sources/Game/main.swift:3:12: error: cannot find 'foo' in scope", projectURL: projectURL)

        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .error)
        #expect(diagnostics[0].range.start.line == 2)
        #expect(diagnostics[0].range.start.character == 11)
        #expect(diagnostics[0].message == "cannot find 'foo' in scope")
    }

    @Test("process diagnostics include every stderr line")
    func processDiagnosticsIncludeStandardErrorLines() {
        let projectURL = URL(fileURLWithPath: "/tmp/Game", isDirectory: true)
        let command = EditorProcessCommand(executablePath: "/usr/bin/swift", arguments: ["package", "resolve"], workingDirectory: projectURL)
        let result = EditorProcessResult(
            command: command,
            exitCode: 0,
            standardOutput: "/tmp/Game/Sources/Game/main.swift:3:12: warning: unused value\n",
            standardError: """
            Fetching https://example.com/Dependency.git
            /tmp/Game/Sources/Game/main.swift:4:8: error: cannot find 'bar' in scope
            """
        )

        let diagnostics = EditorDiagnostic.diagnostics(from: result, projectURL: projectURL)

        #expect(diagnostics.map(\.message) == [
            "unused value",
            "Fetching https://example.com/Dependency.git",
            "cannot find 'bar' in scope"
        ])
        #expect(diagnostics.map(\.severity) == [.warning, .information, .error])
        #expect(diagnostics[1].filePath == "/tmp/Game/Package.swift")
    }

    @Test("LSP semantic tokens decode delta encoded response")
    func semanticTokensDecode() {
        let response: JSONRPCValue = .object([
            "data": .array([.int(0), .int(0), .int(6), .int(15), .int(0), .int(1), .int(4), .int(4), .int(18), .int(0)])
        ])

        let tokens = SourceKitLSPClient.decodeSemanticTokens(
            from: response,
            legend: [
                "namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property",
                "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string"
            ],
            modifiersLegend: []
        )

        #expect(tokens == [
            EditorSemanticToken(line: 0, startCharacter: 0, length: 6, type: "keyword", modifiers: []),
            EditorSemanticToken(line: 1, startCharacter: 4, length: 4, type: "string", modifiers: [])
        ])
    }

    @Test("LSP definition decodes location and location links")
    func definitionDecode() {
        let response: JSONRPCValue = .array([
            .object([
                "uri": .string("file:///tmp/Game/Sources/Game/main.swift"),
                "range": sourceRange(2, 4, 2, 12)
            ]),
            .object([
                "targetUri": .string("file:///tmp/Game/Sources/Game/Player.swift"),
                "targetRange": sourceRange(10, 0, 20, 1),
                "targetSelectionRange": sourceRange(12, 9, 12, 15)
            ])
        ])

        let targets = SourceKitLSPClient.decodeDefinitionTargets(from: response)

        #expect(targets.count == 2)
        #expect(targets[0].filePath == "/tmp/Game/Sources/Game/main.swift")
        #expect(targets[0].selectionRange.start.line == 2)
        #expect(targets[1].filePath == "/tmp/Game/Sources/Game/Player.swift")
        #expect(targets[1].selectionRange.start.character == 9)
    }

    @Test("LSP references hover and document highlights decode")
    func symbolFeatureDecoders() {
        let references = SourceKitLSPClient.decodeReferences(from: .array([
            .object([
                "uri": .string("file:///tmp/Game/Sources/Game/main.swift"),
                "range": sourceRange(3, 2, 3, 8)
            ])
        ]))
        let hover = SourceKitLSPClient.decodeHover(from: .object([
            "contents": .object([
                "kind": .string("markdown"),
                "value": .string("func update()")
            ]),
            "range": sourceRange(3, 2, 3, 8)
        ]))
        let highlights = SourceKitLSPClient.decodeDocumentHighlights(from: .array([
            .object([
                "range": sourceRange(3, 2, 3, 8),
                "kind": .int(3)
            ])
        ]))

        #expect(references.map(\.filePath) == ["/tmp/Game/Sources/Game/main.swift"])
        #expect(hover?.contents == "func update()")
        #expect(hover?.range?.start.character == 2)
        #expect(highlights == [
            EditorDocumentHighlight(
                range: EditorSourceRange(
                    start: EditorSourceLocation(line: 3, character: 2),
                    end: EditorSourceLocation(line: 3, character: 8)
                ),
                kind: .write
            )
        ])
    }

    @Test("package manifest editor adds executable target")
    func manifestEditorAddsExecutableTarget() throws {
        let result = try PackageManifestEditor.edit(simpleManifest, command: .addExecutableTarget(name: "Game", dependencies: ["AdaEngine"]))

        #expect(result.changed)
        #expect(result.manifest.contains(#".executable(name: "Game", targets: ["Game"])"#))
        #expect(result.manifest.contains(#".executableTarget(name: "Game", dependencies: ["AdaEngine"])"#))
    }

    @Test("package manifest editor adds dependency plugin and tests")
    func manifestEditorAddsPackageItems() throws {
        var manifest = simpleManifest
        manifest = try PackageManifestEditor.edit(manifest, command: .addDependency(url: "https://example.com/lib.git", requirement: #"from: "1.0.0""#)).manifest
        manifest = try PackageManifestEditor.edit(manifest, command: .addPlugin(name: "ShaderPlugin", capability: ".buildTool()")).manifest
        manifest = try PackageManifestEditor.edit(manifest, command: .addTestTarget(name: "GameTests", dependencies: ["Game"])).manifest

        #expect(manifest.contains(#".package(url: "https://example.com/lib.git", from: "1.0.0")"#))
        #expect(manifest.contains(#".plugin(name: "ShaderPlugin", targets: ["ShaderPlugin"])"#))
        #expect(manifest.contains(#".plugin(name: "ShaderPlugin", capability: .buildTool(), dependencies: [])"#))
        #expect(manifest.contains(#".testTarget(name: "GameTests", dependencies: ["Game"])"#))
    }

    @Test("package manifest editor adds asset resources to executable target")
    func manifestEditorAddsAssetResources() throws {
        let result = try PackageManifestEditor.edit(
            simpleManifestWithExecutableTarget,
            command: .ensureAssetResources(targetName: nil, assetsPath: "Assets")
        )
        let secondResult = try PackageManifestEditor.edit(
            result.manifest,
            command: .ensureAssetResources(targetName: nil, assetsPath: "Assets")
        )

        #expect(result.changed)
        #expect(result.manifest.contains(#"path: ".""#))
        #expect(result.manifest.contains(#"sources: ["Sources/Game"]"#))
        #expect(result.manifest.contains(#"resources: [.copy("Assets")]"#))
        #expect(!secondResult.changed)
    }

    @Test("package manifest editor requires target when executable target is ambiguous")
    func manifestEditorRequiresTargetForAmbiguousExecutables() throws {
        do {
            _ = try PackageManifestEditor.edit(
                multiExecutableManifest,
                command: .ensureAssetResources(targetName: nil, assetsPath: "Assets")
            )
            Issue.record("Expected manifest edit to throw")
        } catch let error as PackageManifestEditError {
            #expect(error.structuredDescription.contains("unsupportedManifestShape"))
        }

        let result = try PackageManifestEditor.edit(
            multiExecutableManifest,
            command: .ensureAssetResources(targetName: "Tools", assetsPath: "Assets")
        )
        #expect(result.manifest.contains(#".executableTarget(name: "Tools", dependencies: [], path: ".", sources: ["Sources/Tools"], resources: [.copy("Assets")])"#))
    }
}

private actor FakeProcessRunner: EditorProcessRunning {
    var commands: [EditorProcessCommand] = []
    private var results: [EditorProcessResult]
    private let onRun: (@Sendable (EditorProcessCommand) -> Void)?

    init(results: [EditorProcessResult], onRun: (@Sendable (EditorProcessCommand) -> Void)? = nil) {
        self.results = results
        self.onRun = onRun
    }

    func run(_ command: EditorProcessCommand) async -> EditorProcessResult {
        commands.append(command)
        onRun?(command)
        if !results.isEmpty {
            return results.removeFirst()
        }
        return EditorProcessResult(command: command, exitCode: 0, standardOutput: "", standardError: "")
    }

    func semanticTokens(fileURL: URL, language: EditorSourceLanguage, text: String) async -> [EditorSemanticToken] {
        []
    }

    func cancelAll() {}
}

private func findFirstFile(named fileName: String, under root: URL, fileManager: FileManager) -> URL? {
    guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return nil
    }

    for case let url as URL in enumerator where url.lastPathComponent == fileName {
        return url
    }

    return nil
}

private func adaEnginePackageURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .standardizedFileURL
}

private func previewDirectoryName(relativePath: String, declarationID: String) -> String {
    let value = "\(relativePath)-\(declarationID)"
    let scalarSum = value.unicodeScalars.reduce(UInt64(5381)) { partial, scalar in
        ((partial << 5) &+ partial) &+ UInt64(scalar.value)
    }
    return "\(declarationID)-\(String(scalarSum, radix: 16))"
}

private let packageDescriptionJSON = """
{
  "name": "Game",
  "dependencies": [
    {"identity":"adaengine","type":"fileSystem","path":"../AdaEngine"}
  ],
  "products": [
    {"name":"Game","targets":["Game"],"type":{"executable":null}},
    {"name":"GamePlugin","targets":["GamePlugin"],"type":{"plugin":null}}
  ],
  "targets": [
    {"name":"Game","type":"executable","path":"Sources/Game","sources":["main.swift"],"target_dependencies":[],"product_dependencies":["AdaEngine"]},
    {"name":"GameTests","type":"test","path":"Tests/GameTests","sources":["GameTests.swift"],"target_dependencies":["Game"],"product_dependencies":[]},
    {"name":"GamePlugin","type":"plugin","path":"Plugins/GamePlugin","sources":["main.swift"],"target_dependencies":[],"product_dependencies":[]}
  ]
}
"""

private let simpleManifest = """
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Game",
    products: [
    ],
    dependencies: [
    ],
    targets: [
    ]
)
"""

private let simpleManifestWithExecutableTarget = """
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Game",
    products: [
        .executable(name: "Game", targets: ["Game"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(name: "Game", dependencies: [])
    ]
)
"""

private let multiExecutableManifest = """
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Game",
    products: [
        .executable(name: "Game", targets: ["Game"]),
        .executable(name: "Tools", targets: ["Tools"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(name: "Game", dependencies: []),
        .executableTarget(name: "Tools", dependencies: [])
    ]
)
"""

private func sourceRange(_ startLine: Int, _ startCharacter: Int, _ endLine: Int, _ endCharacter: Int) -> JSONRPCValue {
    .object([
        "start": .object([
            "line": .int(startLine),
            "character": .int(startCharacter)
        ]),
        "end": .object([
            "line": .int(endLine),
            "character": .int(endCharacter)
        ])
    ])
}
