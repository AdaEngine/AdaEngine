import Foundation

/// A recently created or opened AdaEditor project persisted in the editor application data.
public struct EditorProjectReference: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var path: String
    public var lastOpenedAt: Date

    public init(id: String = UUID().uuidString, name: String, path: String, lastOpenedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.lastOpenedAt = lastOpenedAt
    }
}

/// Persists AdaEditor project references in `Application Support/AdaEditor/projects.json`.
public struct EditorProjectStore {
    public let storageURL: URL
    public let fileManager: FileManager

    public init(storageURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storageURL = storageURL ?? Self.defaultStorageURL(fileManager: fileManager)
    }

    public static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupport
            .appendingPathComponent("AdaEditor", isDirectory: true)
            .appendingPathComponent("projects.json", isDirectory: false)
    }

    public func loadProjects() throws -> [EditorProjectReference] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([EditorProjectReference].self, from: data)
            .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    @discardableResult
    public func createProject(named name: String, at parentDirectory: URL, openedAt: Date = Date()) throws -> EditorProjectReference {
        let projectName = try normalizedProjectName(name)
        let projectURL = parentDirectory.appendingPathComponent(projectName, isDirectory: true)

        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try createInitialProjectFiles(named: projectName, at: projectURL)
        _ = try ProjectSystem.createDefaultProject(at: projectURL, fileManager: fileManager)

        return try rememberProject(at: projectURL, name: projectName, openedAt: openedAt)
    }

    @discardableResult
    public func openProject(at projectURL: URL, openedAt: Date = Date()) throws -> EditorProjectReference {
        let project = try ProjectSystem.validateProjectLayout(at: projectURL, fileManager: fileManager)
        let displayName = project.project.displayName ?? project.project.name ?? projectURL.lastPathComponent

        return try rememberProject(at: projectURL, name: displayName, openedAt: openedAt)
    }

    @discardableResult
    public func rememberProject(at projectURL: URL, name: String? = nil, openedAt: Date = Date()) throws -> EditorProjectReference {
        var projects = try loadProjects()
        let standardizedPath = projectURL.standardizedFileURL.path
        let displayName = name ?? projectURL.lastPathComponent
        let reference = EditorProjectReference(name: displayName, path: standardizedPath, lastOpenedAt: openedAt)

        projects.removeAll { $0.path == standardizedPath }
        projects.insert(reference, at: 0)
        try saveProjects(projects)
        return reference
    }

    public func saveProjects(_ projects: [EditorProjectReference]) throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(projects.sorted { $0.lastOpenedAt > $1.lastOpenedAt })
        try data.write(to: storageURL, options: [.atomic])
    }

    private func createInitialProjectFiles(named projectName: String, at projectURL: URL) throws {
        try createSwiftPackage(named: projectName, at: projectURL)
        try createAssetsDirectory(at: projectURL)
        try createDefaultScene(named: projectName, at: projectURL)
        try createReadme(named: projectName, at: projectURL)
    }

    private func createSwiftPackage(named projectName: String, at projectURL: URL) throws {
        let manifestURL = projectURL.appendingPathComponent("Package.swift", isDirectory: false)
        guard !fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        let safeTargetName = projectName.replacingOccurrences(of: "-", with: "_")
        let manifest = """
        // swift-tools-version: 6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            products: [
                .executable(name: "\(projectName)", targets: ["\(safeTargetName)"])
            ],
            dependencies: [
                .package(path: "\(Self.escapedManifestString(Self.adaEnginePackageURL().path))")
            ],
            targets: [
                .executableTarget(
                    name: "\(safeTargetName)",
                    dependencies: [.product(name: "AdaEngine", package: "AdaEngine")],
                    path: ".",
                    sources: ["Sources/\(safeTargetName)"],
                    resources: [.copy("Assets")]
                )
            ]
        )
        """

        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        let sourcesURL = projectURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(safeTargetName, isDirectory: true)
        try fileManager.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try "import AdaEngine\nimport Foundation\n\n@main\nstruct Game: App {\n    var body: some AppScene {\n        WindowGroup(assetBundle: .module) {\n            Text(\"Hello, AdaEngine!\")\n        }\n    }\n}\n".write(
            to: sourcesURL.appendingPathComponent("main.swift", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func adaEnginePackageURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL
    }

    private static func escapedManifestString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func createAssetsDirectory(at projectURL: URL) throws {
        let assetsURL = projectURL.appendingPathComponent("Assets", isDirectory: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        let keepURL = assetsURL.appendingPathComponent(".gitkeep", isDirectory: false)
        if !fileManager.fileExists(atPath: keepURL.path) {
            try Data().write(to: keepURL, options: [.atomic])
        }
    }

    private func createDefaultScene(named projectName: String, at projectURL: URL) throws {
        let sceneURL = projectURL.appendingPathComponent(SceneDocumentFormat.defaultScenePath, isDirectory: false)
        let scenesDirectory = sceneURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: scenesDirectory, withIntermediateDirectories: true)

        guard !fileManager.fileExists(atPath: sceneURL.path) else {
            return
        }

        try SceneDocumentFormat.defaultSceneYAML(projectName: projectName).write(
            to: sceneURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private func createReadme(named projectName: String, at projectURL: URL) throws {
        let readmeURL = projectURL.appendingPathComponent("README.md", isDirectory: false)
        guard !fileManager.fileExists(atPath: readmeURL.path) else {
            return
        }

        let readme = """
        # \(projectName)

        Created with AdaEditor.

        ## Structure

        - `Package.swift` — SwiftPM package manifest.
        - `.ada/project.json` — AdaEditor project metadata.
        - `Sources/` — game source files.
        - `Assets/` — game assets and scene documents.
        """
        try readme.write(to: readmeURL, atomically: true, encoding: .utf8)
    }

    private func normalizedProjectName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EditorProjectStoreError.emptyProjectName
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let normalizedScalars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(normalizedScalars)
    }
}

public enum EditorProjectStoreError: Error, Equatable, Sendable {
    case emptyProjectName
}
