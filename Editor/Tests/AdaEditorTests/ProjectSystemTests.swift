@testable import AdaEditor
import Foundation
import Testing

@Suite("ProjectSystem")
struct ProjectSystemTests {
    @Test("loads committed minimal project.json fixture")
    func loadsMinimalProjectJSONFixture() throws {
        let project = try loadFixture("valid/minimal.project.json")

        #expect(project.schemaVersion == 1)
        #expect(project.build.system == .swiftpm)
        #expect(project.buildSystem == .swiftpm)
        #expect(project.project.name == nil)
        #expect(project.paths.sources == nil)
        #expect(project.paths.assets == nil)
        #expect(project.paths.build == nil)
        #expect(project.paths.generated == nil)
        #expect(project.paths.run.workingDirectory == nil)
        #expect(project.run.workingDirectory == nil)
        #expect(project.ai.mcp.enabled)
    }

    @Test("loads committed full project.json fixture and exposes metadata")
    func loadsFullProjectJSONFixture() throws {
        let project = try loadFixture("valid/full.project.json")

        #expect(project.schemaVersion == 1)
        #expect(project.project.id == "com.example.spacegame")
        #expect(project.project.name == "SpaceGame")
        #expect(project.project.displayName == "Space Game")
        #expect(project.project.bundleIdentifier == "com.example.spacegame")
        #expect(project.engine.minimumVersion == "0.1.0")
        #expect(project.engine.package == "AdaEngine")
        #expect(project.paths.sources == "Sources")
        #expect(project.paths.assets == "Assets")
        #expect(project.paths.build == ".build")
        #expect(project.paths.generated == ".ada/generated")
        #expect(project.paths.run.workingDirectory == "Demos/Games/SpaceGame")
        #expect(project.build.system == .swiftpm)
        #expect(project.build.configuration == "debug")
        #expect(project.build.targets == ["Demos/Games/SpaceGame"])
        #expect(project.run.executable == ".build/debug/SpaceGame")
        #expect(project.run.arguments == ["--debug"])
        #expect(project.run.environment == ["ADA_LOG_LEVEL": "debug"])
        #expect(project.run.workingDirectory == "Demos/Games/SpaceGame")
        #expect(project.editor.startupScene == "Assets/Scenes/Main.scene")
        #expect(project.ai.mcp.allowedResourceRoots == ["Sources", "Assets", "Docs"])
    }

    @Test("loads legacy draft buildSystem field")
    func loadsLegacyDraftBuildSystem() throws {
        let project = try ProjectSystem.loadProject(from: Data(#"{"schemaVersion":1,"buildSystem":"swiftpm","paths":{}}"#.utf8))

        #expect(project.schemaVersion == 1)
        #expect(project.build.system == .swiftpm)
        #expect(project.buildSystem == .swiftpm)
    }

    @Test("detects Ada project only when metadata and Package.swift exist")
    func detectsAdaProject() throws {
        let projectURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(projectURL) }

        try "// swift-tools-version: 6.2\n".write(to: projectURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        #expect(!ProjectSystem.isAdaProject(at: projectURL))

        try FileManager.default.createDirectory(at: projectURL.appendingPathComponent(".ada"), withIntermediateDirectories: true)
        try "{}".write(to: ProjectSystem.metadataURL(forProjectAt: projectURL), atomically: true, encoding: .utf8)

        #expect(ProjectSystem.isAdaProject(at: projectURL))
    }

    @Test("missing project.json returns structured error")
    func missingProjectJSON() throws {
        let projectURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(projectURL) }

        do {
            _ = try ProjectSystem.loadProject(at: projectURL)
            Issue.record("Expected loadProject to throw")
        } catch let error as ProjectSystemError {
            #expect(error == .metadataFileMissing(path: ".ada/project.json"))
            #expect(error.code == "project.metadataFileMissing")
            #expect(error.fieldPath == ".ada/project.json")
        }
    }

    @Test("invalid JSON returns structured error")
    func invalidJSON() throws {
        do {
            _ = try ProjectSystem.loadProject(from: Data("{".utf8))
            Issue.record("Expected loadProject to throw")
        } catch let error as ProjectSystemError {
            #expect(error.code == "project.invalidJSON")
            #expect(error.fieldPath == ".ada/project.json")
        }
    }

    @Test("committed negative fixtures are rejected", arguments: [
        ("invalid/missing-schema-version.project.json", "project.missingSchemaVersion", "schemaVersion"),
        ("invalid/unsupported-schema-version.project.json", "project.unsupportedSchemaVersion", "schemaVersion"),
        ("invalid/invalid-path-syntax.project.json", "project.invalidPath", "paths.assets"),
        ("invalid/path-traversal.project.json", "project.pathTraversalNotAllowed", "paths.sources"),
        ("invalid/absolute-posix-path.project.json", "project.absolutePathNotAllowed", "paths.build"),
        ("invalid/absolute-windows-path.project.json", "project.absolutePathNotAllowed", "run.executable")
    ])
    func committedNegativeFixturesAreRejected(fixture: String, code: String, fieldPath: String) throws {
        do {
            _ = try loadFixture(fixture)
            Issue.record("Expected fixture \(fixture) to throw")
        } catch let error as ProjectSystemError {
            #expect(error.code == code)
            #expect(error.fieldPath == fieldPath)
        }
    }

    @Test("unsupported build system returns structured error")
    func unsupportedBuildSystem() throws {
        do {
            _ = try ProjectSystem.loadProject(from: Data(#"{"schemaVersion":1,"build":{"system":"xcode"}}"#.utf8))
            Issue.record("Expected loadProject to throw")
        } catch let error as ProjectSystemError {
            #expect(error == .unknownBuildSystem(path: "build.system", value: "xcode", supportedValues: ["swiftpm"]))
            #expect(error.code == "project.unknownBuildSystem")
            #expect(error.fieldPath == "build.system")
        }
    }

    @Test("invalid path values are rejected", arguments: [
        (#"{"schemaVersion":1,"paths":{"sources":"/Sources"}}"#, "project.absolutePathNotAllowed", "paths.sources"),
        (#"{"schemaVersion":1,"paths":{"assets":"~/Assets"}}"#, "project.absolutePathNotAllowed", "paths.assets"),
        (#"{"schemaVersion":1,"paths":{"generated":".ada//generated"}}"#, "project.invalidPath", "paths.generated"),
        (#"{"schemaVersion":1,"paths":{"run":{"workingDirectory":"../run"}}}"#, "project.pathTraversalNotAllowed", "paths.run.workingDirectory"),
        (#"{"schemaVersion":1,"build":{"targets":["Sources","../Secrets"]}}"#, "project.pathTraversalNotAllowed", "build.targets.1"),
        (#"{"schemaVersion":1,"ai":{"mcp":{"allowedResourceRoots":["Sources","C:\\Secrets"]}}}"#, "project.absolutePathNotAllowed", "ai.mcp.allowedResourceRoots.1"),
        (#"{"schemaVersion":1,"editor":{"startupScene":"https://example.com/scene"}}"#, "project.invalidPath", "editor.startupScene")
    ])
    func invalidPathsAreRejected(json: String, code: String, fieldPath: String) throws {
        do {
            _ = try ProjectSystem.loadProject(from: Data(json.utf8))
            Issue.record("Expected loadProject to throw")
        } catch let error as ProjectSystemError {
            #expect(error.code == code)
            #expect(error.fieldPath == fieldPath)
        }
    }

    @Test("creates default project.json for existing SwiftPM project")
    func createsDefaultProjectJSON() throws {
        let projectURL = try makeTemporaryDirectory(named: "CreatedAdaProject")
        defer { removeTemporaryDirectory(projectURL) }

        try "// swift-tools-version: 6.2\n".write(to: projectURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let project = try ProjectSystem.createDefaultProject(at: projectURL)
        let metadataURL = ProjectSystem.metadataURL(forProjectAt: projectURL)
        let generated = try String(contentsOf: metadataURL, encoding: .utf8)

        #expect(project == ProjectSystem.defaultProject(projectName: "CreatedAdaProject"))
        #expect(generated == expectedCreatedProjectJSON)
    }

    @Test("default project.json snapshot")
    func defaultProjectJSONSnapshot() throws {
        let json = try ProjectSystem.defaultProjectJSON()

        #expect(json == expectedDefaultProjectJSON)
    }

    @Test("create default requires SwiftPM project")
    func createDefaultRequiresSwiftPMProject() throws {
        let projectURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(projectURL) }

        do {
            _ = try ProjectSystem.createDefaultProject(at: projectURL)
            Issue.record("Expected createDefaultProject to throw")
        } catch let error as ProjectSystemError {
            #expect(error == .swiftPackageManifestMissing(path: "Package.swift"))
            #expect(error.code == "project.swiftPackageManifestMissing")
        }
    }
}

private let expectedDefaultProjectJSON = """
{
  "ai" : {
    "mcp" : {
      "allowedResourceRoots" : [

      ],
      "enabled" : true
    }
  },
  "build" : {
    "system" : "swiftpm",
    "targets" : [

    ]
  },
  "editor" : {
    "startupScene" : "Assets/Scenes/Main.ascn"
  },
  "engine" : {

  },
  "paths" : {
    "assets" : "Assets",
    "build" : ".build",
    "run" : {
      "workingDirectory" : "."
    },
    "sources" : "Sources"
  },
  "project" : {
    "name" : "AdaEngineProject"
  },
  "run" : {
    "arguments" : [

    ],
    "environment" : {

    },
    "workingDirectory" : "."
  },
  "schemaVersion" : 1
}
"""

private let expectedCreatedProjectJSON = expectedDefaultProjectJSON.replacingOccurrences(
    of: "\"name\" : \"AdaEngineProject\"",
    with: "\"name\" : \"CreatedAdaProject\""
)

private func loadFixture(_ path: String) throws -> AdaProject {
    let data = try Data(contentsOf: fixtureURL(path))
    return try ProjectSystem.loadProject(from: data, sourcePath: path)
}

private func fixtureURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/ProjectSystem")
        .appendingPathComponent(path)
}

private func makeTemporaryDirectory(named name: String? = nil) throws -> URL {
    let directoryName = name ?? "ProjectSystemTests-\(UUID().uuidString)"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(directoryName, isDirectory: true)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func removeTemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
