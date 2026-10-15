import AdaAssets
import AdaScripting
import Foundation
import MCP

/// Runs an agent-authored AdaScript voxel generator in an isolated VM and saves the result as a MagicaVoxel file.
@MainActor
struct EditorAgentVoxelToolService {
    private let projectURL: URL

    init(projectURL: URL) {
        self.projectURL = projectURL.resolvingSymlinksInPath().standardizedFileURL
    }

    func execute(arguments: [String: Value]) throws -> [String: Any] {
        guard let source = arguments["source"]?.stringValue, !source.isEmpty else { throw Failure("Missing source.") }
        guard let destination = arguments["destination"]?.stringValue, !destination.isEmpty else { throw Failure("Missing destination.") }
        let url = try destinationURL(destination)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw Failure("Destination exists: \(destination). Choose a new name; existing assets are preserved.")
        }
        let result: AdaScriptVoxelResult
        do {
            result = try AdaScriptVoxelGenerator.generate(source: source)
        } catch let error as AdaScriptError {
            throw Failure("Voxel script failed: \(error.description)")
        }
        let data = try VOXWriter().encode(model: result.model, palette: result.palette)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        let assets = try assetsURL()
        let used = Set(result.model.voxels.map(\.colorIndex)).sorted()
        return [
            "path": destination,
            "assetReference": "@res://" + url.pathComponents.dropFirst(assets.pathComponents.count).joined(separator: "/"),
            "size": [result.model.sizeX, result.model.sizeY, result.model.sizeZ],
            "voxelCount": result.model.voxels.count,
            "paletteIndicesUsed": used.map { Int($0) },
            "bytes": data.count,
            "requiresRebuild": true,
        ]
    }

    private func assetsURL() throws -> URL {
        let project = try ProjectSystem.loadProject(at: projectURL)
        return projectURL.appendingPathComponent(project.paths.assets ?? "Assets").resolvingSymlinksInPath().standardizedFileURL
    }

    private func destinationURL(_ path: String) throws -> URL {
        guard !path.hasPrefix("/"), !path.hasPrefix("~") else { throw Failure("Use a project-relative Assets path.") }
        let url = projectURL.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        let root = try assetsURL()
        guard url.pathComponents.starts(with: root.pathComponents), url.pathComponents.count > root.pathComponents.count,
            url.pathExtension.lowercased() == "vox"
        else { throw Failure("Destination must be a .vox path inside Assets.") }
        return url
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
