import Foundation

/// Reads, validates, and creates Ada project metadata stored at `.ada/project.json`.
public enum ProjectSystem {
    public static let metadataDirectoryName = ".ada"
    public static let metadataFileName = "project.json"
    public static let currentSchemaVersion = 1
    public static let supportedSchemaVersions: Set<Int> = [currentSchemaVersion]
    public static let knownBuildSystems: Set<String> = ["swiftpm"]

    public static func metadataURL(forProjectAt projectURL: URL) -> URL {
        projectURL
            .appendingPathComponent(metadataDirectoryName, isDirectory: true)
            .appendingPathComponent(metadataFileName, isDirectory: false)
    }

    public static func isAdaProject(at projectURL: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: metadataURL(forProjectAt: projectURL).path)
            && fileManager.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path)
    }

    public static func loadProject(at projectURL: URL, fileManager: FileManager = .default) throws(ProjectSystemError) -> AdaProject {
        let metadataURL = metadataURL(forProjectAt: projectURL)

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw .metadataFileMissing(path: ProjectSystemPath.metadataFile)
        }

        let data: Data
        do {
            data = try Data(contentsOf: metadataURL)
        } catch {
            throw .fileReadFailed(path: ProjectSystemPath.metadataFile, message: error.localizedDescription)
        }

        return try loadProject(from: data, sourcePath: ProjectSystemPath.metadataFile)
    }

    public static func loadProject(from data: Data, sourcePath: String = ProjectSystemPath.metadataFile) throws(ProjectSystemError) -> AdaProject {
        let decoder = JSONDecoder()
        let project: AdaProject

        do {
            project = try decoder.decode(AdaProject.self, from: data)
        } catch let error as DecodingError {
            throw decodeError(from: error, sourcePath: sourcePath)
        } catch {
            throw .invalidJSON(path: sourcePath, message: error.localizedDescription)
        }

        return try migrateAndValidate(project, sourcePath: sourcePath)
    }

    @discardableResult
    public static func createDefaultProject(at projectURL: URL, fileManager: FileManager = .default) throws(ProjectSystemError) -> AdaProject {
        let packageURL = projectURL.appendingPathComponent("Package.swift", isDirectory: false)
        guard fileManager.fileExists(atPath: packageURL.path) else {
            throw .swiftPackageManifestMissing(path: "Package.swift")
        }

        let project = defaultProject(projectName: projectURL.lastPathComponent)
        let metadataDirectory = projectURL.appendingPathComponent(metadataDirectoryName, isDirectory: true)
        let metadataURL = metadataURL(forProjectAt: projectURL)

        do {
            try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
            let data = try encode(project)
            try data.write(to: metadataURL, options: [.atomic])
        } catch let error as EncodingError {
            throw .encodingFailed(message: error.localizedDescription)
        } catch {
            throw .fileWriteFailed(path: ProjectSystemPath.metadataFile, message: error.localizedDescription)
        }

        return project
    }

    public static func defaultProject(projectName: String = "AdaEngineProject") -> AdaProject {
        AdaProject(
            schemaVersion: currentSchemaVersion,
            project: .init(name: projectName),
            engine: .init(),
            paths: .init(
                sources: "Sources",
                assets: "Assets",
                build: ".build",
                generated: nil,
                run: .init(workingDirectory: ".")
            ),
            build: .init(system: .swiftpm),
            run: .init(executable: nil, arguments: [], environment: [:], workingDirectory: "."),
            editor: .init(startupScene: SceneDocumentFormat.defaultScenePath),
            ai: .init(mcp: .init(enabled: true))
        )
    }

    public static func defaultProjectJSON() throws(ProjectSystemError) -> String {
        do {
            return String(decoding: try encode(defaultProject()), as: UTF8.self)
        } catch let error as EncodingError {
            throw .encodingFailed(message: error.localizedDescription)
        } catch {
            throw .encodingFailed(message: error.localizedDescription)
        }
    }

    public static func validate(_ project: AdaProject, sourcePath: String = ProjectSystemPath.metadataFile) throws(ProjectSystemError) {
        _ = try migrateAndValidate(project, sourcePath: sourcePath)
    }

    /// Future schema-version migration entry point. Currently validates and returns v1 unchanged.
    public static func migrateAndValidate(_ project: AdaProject, sourcePath: String = ProjectSystemPath.metadataFile) throws(ProjectSystemError) -> AdaProject {
        guard supportedSchemaVersions.contains(project.schemaVersion) else {
            throw .unsupportedSchemaVersion(path: "schemaVersion", version: project.schemaVersion, supportedVersions: supportedSchemaVersions.sorted())
        }

        guard knownBuildSystems.contains(project.build.system.rawValue) else {
            throw .unknownBuildSystem(path: "build.system", value: project.build.system.rawValue, supportedValues: knownBuildSystems.sorted())
        }

        try validateRelativePath(project.paths.sources, keyPath: "paths.sources")
        try validateRelativePath(project.paths.assets, keyPath: "paths.assets")
        try validateRelativePath(project.paths.build, keyPath: "paths.build")
        try validateRelativePath(project.paths.generated, keyPath: "paths.generated")
        try validateRelativePath(project.paths.run.workingDirectory, keyPath: "paths.run.workingDirectory")
        try validateRelativePath(project.run.workingDirectory, keyPath: "run.workingDirectory")
        try validateRelativePath(project.run.executable, keyPath: "run.executable")
        try validateRelativePath(project.editor.startupScene, keyPath: "editor.startupScene")
        try validatePathArray(project.build.targets, keyPath: "build.targets")
        try validatePathArray(project.ai.mcp.allowedResourceRoots, keyPath: "ai.mcp.allowedResourceRoots")
        try validateRelativePath(project.ai.agent.target.cwd, keyPath: "ai.agent.target.cwd")
        try validatePathArray(project.ai.agent.skillsDirectories, keyPath: "ai.agent.skillsDirectories")

        return project
    }

    private static func encode(_ project: AdaProject) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(project)
    }

    private static func decodeError(from error: DecodingError, sourcePath: String) -> ProjectSystemError {
        switch error {
        case .keyNotFound(let key, let context) where key.stringValue == "schemaVersion":
            .missingSchemaVersion(path: codingPathString(context.codingPath + [key]))
        case .dataCorrupted(let context):
            .invalidJSON(path: sourcePath, message: context.debugDescription)
        case .keyNotFound(let key, let context):
            .missingRequiredField(path: codingPathString(context.codingPath + [key]), message: context.debugDescription)
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            .invalidField(path: codingPathString(context.codingPath), message: context.debugDescription)
        @unknown default:
            .invalidJSON(path: sourcePath, message: error.localizedDescription)
        }
    }

    private static func codingPathString(_ codingPath: [CodingKey]) -> String {
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? ProjectSystemPath.metadataFile : path
    }

    private static func validatePathArray(_ paths: [String], keyPath: String) throws(ProjectSystemError) {
        for (index, path) in paths.enumerated() {
            try validateRelativePath(path, keyPath: "\(keyPath).\(index)")
        }
    }

    private static func validateRelativePath(_ path: String?, keyPath: String) throws(ProjectSystemError) {
        guard let path else { return }

        guard !path.isEmpty else {
            throw .invalidPath(path: keyPath, value: path, reason: "Path must not be empty.")
        }

        if path.hasPrefix("/") || path.hasPrefix("~") || isWindowsAbsolutePath(path) || path.hasPrefix("\\\\") {
            throw .absolutePathNotAllowed(path: keyPath, value: path)
        }

        if path.contains("\\") {
            throw .invalidPath(path: keyPath, value: path, reason: "Use POSIX-style '/' separators.")
        }

        if path.unicodeScalars.contains(where: { $0.value == 0 }) {
            throw .invalidPath(path: keyPath, value: path, reason: "NUL bytes are not allowed.")
        }

        if path.contains("://") {
            throw .invalidPath(path: keyPath, value: path, reason: "URLs are not allowed.")
        }

        let segments = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if segments.contains(where: { $0.isEmpty }) {
            throw .invalidPath(path: keyPath, value: path, reason: "Empty path segments are not allowed.")
        }

        if segments.contains("..") {
            throw .pathTraversalNotAllowed(path: keyPath, value: path)
        }
    }

    private static func isWindowsAbsolutePath(_ path: String) -> Bool {
        guard path.count >= 3 else { return false }

        let scalars = Array(path.unicodeScalars)
        return CharacterSet.letters.contains(scalars[0])
            && scalars[1] == ":"
            && (scalars[2] == "\\" || scalars[2] == "/")
    }
}

public enum ProjectSystemPath {
    public static let metadataFile = ".ada/project.json"
}

public struct AdaProject: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var project: AdaProjectMetadata
    public var engine: AdaProjectEngine
    public var paths: AdaProjectPaths
    public var build: AdaProjectBuild
    public var run: AdaProjectRun
    public var editor: AdaProjectEditor
    public var ai: AdaProjectAI

    public init(
        schemaVersion: Int,
        project: AdaProjectMetadata = AdaProjectMetadata(),
        engine: AdaProjectEngine = AdaProjectEngine(),
        paths: AdaProjectPaths = AdaProjectPaths(),
        build: AdaProjectBuild = AdaProjectBuild(),
        run: AdaProjectRun = AdaProjectRun(),
        editor: AdaProjectEditor = AdaProjectEditor(),
        ai: AdaProjectAI = AdaProjectAI()
    ) {
        self.schemaVersion = schemaVersion
        self.project = project
        self.engine = engine
        self.paths = paths
        self.build = build
        self.run = run
        self.editor = editor
        self.ai = ai
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, project, engine, paths, build, run, editor, ai
        case legacyBuildSystem = "buildSystem"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        project = try container.decodeIfPresent(AdaProjectMetadata.self, forKey: .project) ?? AdaProjectMetadata()
        engine = try container.decodeIfPresent(AdaProjectEngine.self, forKey: .engine) ?? AdaProjectEngine()
        paths = try container.decodeIfPresent(AdaProjectPaths.self, forKey: .paths) ?? AdaProjectPaths()
        if let build = try container.decodeIfPresent(AdaProjectBuild.self, forKey: .build) {
            self.build = build
        } else if let legacyBuildSystem = try container.decodeIfPresent(AdaProjectBuildSystem.self, forKey: .legacyBuildSystem) {
            self.build = AdaProjectBuild(system: legacyBuildSystem)
        } else {
            self.build = AdaProjectBuild()
        }
        run = try container.decodeIfPresent(AdaProjectRun.self, forKey: .run) ?? AdaProjectRun()
        editor = try container.decodeIfPresent(AdaProjectEditor.self, forKey: .editor) ?? AdaProjectEditor()
        ai = try container.decodeIfPresent(AdaProjectAI.self, forKey: .ai) ?? AdaProjectAI()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(project, forKey: .project)
        try container.encode(engine, forKey: .engine)
        try container.encode(paths, forKey: .paths)
        try container.encode(build, forKey: .build)
        try container.encode(run, forKey: .run)
        try container.encode(editor, forKey: .editor)
        try container.encode(ai, forKey: .ai)
    }

    /// Compatibility accessor for project.json drafts that used a top-level `buildSystem` field.
    public var buildSystem: AdaProjectBuildSystem {
        get { build.system }
        set { build.system = newValue }
    }
}

public struct AdaProjectMetadata: Codable, Equatable, Sendable {
    public var id: String?
    public var name: String?
    public var displayName: String?
    public var bundleIdentifier: String?

    public init(id: String? = nil, name: String? = nil, displayName: String? = nil, bundleIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct AdaProjectEngine: Codable, Equatable, Sendable {
    public var minimumVersion: String?
    public var package: String?

    public init(minimumVersion: String? = nil, package: String? = nil) {
        self.minimumVersion = minimumVersion
        self.package = package
    }
}

public struct AdaProjectPaths: Codable, Equatable, Sendable {
    public var sources: String?
    public var assets: String?
    public var build: String?
    public var generated: String?
    public var run: AdaProjectRunPaths

    public init(
        sources: String? = nil,
        assets: String? = nil,
        build: String? = nil,
        generated: String? = nil,
        run: AdaProjectRunPaths = AdaProjectRunPaths()
    ) {
        self.sources = sources
        self.assets = assets
        self.build = build
        self.generated = generated
        self.run = run
    }

    private enum CodingKeys: String, CodingKey { case sources, assets, build, generated, run }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sources = try container.decodeIfPresent(String.self, forKey: .sources)
        assets = try container.decodeIfPresent(String.self, forKey: .assets)
        build = try container.decodeIfPresent(String.self, forKey: .build)
        generated = try container.decodeIfPresent(String.self, forKey: .generated)
        run = try container.decodeIfPresent(AdaProjectRunPaths.self, forKey: .run) ?? AdaProjectRunPaths()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(assets, forKey: .assets)
        try container.encodeIfPresent(build, forKey: .build)
        try container.encodeIfPresent(generated, forKey: .generated)
        try container.encode(run, forKey: .run)
    }
}

public struct AdaProjectRunPaths: Codable, Equatable, Sendable {
    public var workingDirectory: String?

    public init(workingDirectory: String? = nil) {
        self.workingDirectory = workingDirectory
    }
}

public struct AdaProjectBuild: Codable, Equatable, Sendable {
    public var system: AdaProjectBuildSystem
    public var configuration: String?
    public var targets: [String]

    public init(system: AdaProjectBuildSystem = .swiftpm, configuration: String? = nil, targets: [String] = []) {
        self.system = system
        self.configuration = configuration
        self.targets = targets
    }

    private enum CodingKeys: String, CodingKey { case system, configuration, targets }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        system = try container.decodeIfPresent(AdaProjectBuildSystem.self, forKey: .system) ?? .swiftpm
        configuration = try container.decodeIfPresent(String.self, forKey: .configuration)
        targets = try container.decodeIfPresent([String].self, forKey: .targets) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(system, forKey: .system)
        try container.encodeIfPresent(configuration, forKey: .configuration)
        try container.encode(targets, forKey: .targets)
    }
}

public struct AdaProjectRun: Codable, Equatable, Sendable {
    public var executable: String?
    public var arguments: [String]
    public var environment: [String: String]
    public var workingDirectory: String?

    public init(executable: String? = nil, arguments: [String] = [], environment: [String: String] = [:], workingDirectory: String? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
    }

    private enum CodingKeys: String, CodingKey { case executable, arguments, environment, workingDirectory }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        executable = try container.decodeIfPresent(String.self, forKey: .executable)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(executable, forKey: .executable)
        try container.encode(arguments, forKey: .arguments)
        try container.encode(environment, forKey: .environment)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
    }
}

public struct AdaProjectEditor: Codable, Equatable, Sendable {
    public var startupScene: String?

    public init(startupScene: String? = nil) {
        self.startupScene = startupScene
    }
}

public struct AdaProjectAI: Codable, Equatable, Sendable {
    public var mcp: AdaProjectMCP
    public var agent: AdaProjectAgent

    public init(mcp: AdaProjectMCP = AdaProjectMCP(), agent: AdaProjectAgent = AdaProjectAgent()) {
        self.mcp = mcp
        self.agent = agent
    }

    private enum CodingKeys: String, CodingKey { case mcp, agent }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mcp = try container.decodeIfPresent(AdaProjectMCP.self, forKey: .mcp) ?? AdaProjectMCP()
        agent = try container.decodeIfPresent(AdaProjectAgent.self, forKey: .agent) ?? AdaProjectAgent()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mcp, forKey: .mcp)
        if agent != AdaProjectAgent() {
            try container.encode(agent, forKey: .agent)
        }
    }
}

public struct AdaProjectMCP: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var allowedResourceRoots: [String]

    public init(enabled: Bool = true, allowedResourceRoots: [String] = []) {
        self.enabled = enabled
        self.allowedResourceRoots = allowedResourceRoots
    }

    private enum CodingKeys: String, CodingKey { case enabled, allowedResourceRoots }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        allowedResourceRoots = try container.decodeIfPresent([String].self, forKey: .allowedResourceRoots) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(allowedResourceRoots, forKey: .allowedResourceRoots)
    }
}

public struct AdaProjectAgent: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var target: AdaProjectAgentTarget
    public var permissionMode: AdaProjectAgentPermissionMode
    public var skillsDirectories: [String]

    public init(
        enabled: Bool = false,
        target: AdaProjectAgentTarget = AdaProjectAgentTarget(),
        permissionMode: AdaProjectAgentPermissionMode = .allowOnce,
        skillsDirectories: [String] = [".skills", ".codex/skills"]
    ) {
        self.enabled = enabled
        self.target = target
        self.permissionMode = permissionMode
        self.skillsDirectories = skillsDirectories
    }

    private enum CodingKeys: String, CodingKey { case enabled, target, permissionMode, skillsDirectories }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        target = try container.decodeIfPresent(AdaProjectAgentTarget.self, forKey: .target) ?? AdaProjectAgentTarget()
        permissionMode = try container.decodeIfPresent(AdaProjectAgentPermissionMode.self, forKey: .permissionMode) ?? .allowOnce
        skillsDirectories = try container.decodeIfPresent([String].self, forKey: .skillsDirectories) ?? [".skills", ".codex/skills"]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(target, forKey: .target)
        try container.encode(permissionMode, forKey: .permissionMode)
        try container.encode(skillsDirectories, forKey: .skillsDirectories)
    }
}

public struct AdaProjectAgentTarget: Codable, Equatable, Sendable {
    public var command: String?
    public var arguments: [String]
    public var environment: [String: String]
    public var cwd: String?

    public init(command: String? = nil, arguments: [String] = [], environment: [String: String] = [:], cwd: String? = nil) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.cwd = cwd
    }

    private enum CodingKeys: String, CodingKey { case command, arguments, environment, cwd }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encode(arguments, forKey: .arguments)
        try container.encode(environment, forKey: .environment)
        try container.encodeIfPresent(cwd, forKey: .cwd)
    }
}

public enum AdaProjectAgentPermissionMode: String, Codable, Equatable, Sendable {
    case allowOnce
    case deny
}

public struct AdaProjectBuildSystem: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let swiftpm = AdaProjectBuildSystem(rawValue: "swiftpm")
}

public enum ProjectSystemError: Error, Equatable, Sendable {
    case metadataFileMissing(path: String)
    case swiftPackageManifestMissing(path: String)
    case fileReadFailed(path: String, message: String)
    case fileWriteFailed(path: String, message: String)
    case invalidJSON(path: String, message: String)
    case missingSchemaVersion(path: String)
    case unsupportedSchemaVersion(path: String, version: Int, supportedVersions: [Int])
    case missingRequiredField(path: String, message: String)
    case invalidField(path: String, message: String)
    case unknownBuildSystem(path: String, value: String, supportedValues: [String])
    case absolutePathNotAllowed(path: String, value: String)
    case pathTraversalNotAllowed(path: String, value: String)
    case invalidPath(path: String, value: String, reason: String)
    case encodingFailed(message: String)

    public var code: String {
        switch self {
        case .metadataFileMissing: "project.metadataFileMissing"
        case .swiftPackageManifestMissing: "project.swiftPackageManifestMissing"
        case .fileReadFailed: "project.fileReadFailed"
        case .fileWriteFailed: "project.fileWriteFailed"
        case .invalidJSON: "project.invalidJSON"
        case .missingSchemaVersion: "project.missingSchemaVersion"
        case .unsupportedSchemaVersion: "project.unsupportedSchemaVersion"
        case .missingRequiredField: "project.missingRequiredField"
        case .invalidField: "project.invalidField"
        case .unknownBuildSystem: "project.unknownBuildSystem"
        case .absolutePathNotAllowed: "project.absolutePathNotAllowed"
        case .pathTraversalNotAllowed: "project.pathTraversalNotAllowed"
        case .invalidPath: "project.invalidPath"
        case .encodingFailed: "project.encodingFailed"
        }
    }

    public var message: String {
        switch self {
        case .metadataFileMissing(let path): "Ada project metadata file is missing at \(path)."
        case .swiftPackageManifestMissing(let path): "SwiftPM manifest is missing at \(path)."
        case .fileReadFailed(let path, let message): "Failed to read \(path): \(message)"
        case .fileWriteFailed(let path, let message): "Failed to write \(path): \(message)"
        case .invalidJSON(let path, let message): "Invalid JSON in \(path): \(message)"
        case .missingSchemaVersion(let path): "Missing required schemaVersion at \(path)."
        case .unsupportedSchemaVersion(_, let version, let supportedVersions):
            "Unsupported Ada project schemaVersion \(version). Supported versions: \(supportedVersions.map(String.init).joined(separator: ", "))."
        case .missingRequiredField(let path, let message): "Missing required field at \(path): \(message)"
        case .invalidField(let path, let message): "Invalid field at \(path): \(message)"
        case .unknownBuildSystem(_, let value, let supportedValues):
            "Unknown build system '\(value)'. Supported values: \(supportedValues.joined(separator: ", "))."
        case .absolutePathNotAllowed(let path, let value): "Absolute path is not allowed at \(path): \(value)"
        case .pathTraversalNotAllowed(let path, let value): "Path traversal is not allowed at \(path): \(value)"
        case .invalidPath(let path, let value, let reason): "Invalid path at \(path): \(value). \(reason)"
        case .encodingFailed(let message): "Failed to encode Ada project metadata: \(message)"
        }
    }

    public var fieldPath: String? {
        switch self {
        case .metadataFileMissing(let path),
             .swiftPackageManifestMissing(let path),
             .fileReadFailed(let path, _),
             .fileWriteFailed(let path, _),
             .invalidJSON(let path, _),
             .missingSchemaVersion(let path),
             .unsupportedSchemaVersion(let path, _, _),
             .missingRequiredField(let path, _),
             .invalidField(let path, _),
             .unknownBuildSystem(let path, _, _),
             .absolutePathNotAllowed(let path, _),
             .pathTraversalNotAllowed(let path, _),
             .invalidPath(let path, _, _):
            path
        case .encodingFailed:
            nil
        }
    }
}
