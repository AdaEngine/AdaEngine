import AdaAssets
import AdaScripting
import Foundation
import MCP

/// Runs an agent-authored AdaScript generator in an isolated VM and saves the result as a model asset:
/// `editor.voxel.generate` writes a MagicaVoxel `.vox`, `editor.model.generate` a binary glTF `.glb`.
@MainActor
struct EditorAgentGeneratorToolService {
    static let toolNames: Set<String> = ["editor.voxel.generate", "editor.model.generate"]

    private let projectURL: URL

    init(projectURL: URL) {
        self.projectURL = projectURL.resolvingSymlinksInPath().standardizedFileURL
    }

    func execute(name: String, arguments: [String: Value]) throws -> [String: Any] {
        guard let source = arguments["source"]?.stringValue, !source.isEmpty else { throw Failure("Missing source.") }
        guard let destination = arguments["destination"]?.stringValue, !destination.isEmpty else { throw Failure("Missing destination.") }
        let isVoxel = name == "editor.voxel.generate"
        let url = try destinationURL(destination, extension: isVoxel ? "vox" : "glb")
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw Failure("Destination exists: \(destination). Choose a new name; existing assets are preserved.")
        }
        let data: Data
        var summary: [String: Any]
        do {
            if isVoxel {
                let result = try AdaScriptVoxelGenerator.generate(source: source)
                data = try VOXWriter().encode(model: result.model, palette: result.palette)
                summary = [
                    "size": [result.model.sizeX, result.model.sizeY, result.model.sizeZ],
                    "voxelCount": result.model.voxels.count,
                    "paletteIndicesUsed": Set(result.model.voxels.map(\.colorIndex)).sorted().map { Int($0) },
                ]
            } else {
                let model = try AdaScriptModelGenerator.generate(source: source)
                data = try GLBWriter().encode(model)
                let meshes = model.nodes.compactMap(\.mesh)
                summary = [
                    "parts": model.nodes.map { node -> [String: Any] in
                        var part: [String: Any] = ["name": node.name, "hasMesh": node.mesh != nil]
                        if let parent = node.parent { part["parent"] = model.nodes[parent].name }
                        return part
                    },
                    "materials": model.materials.map(\.name),
                    "vertexCount": meshes.reduce(0) { $0 + $1.positions.count },
                    "triangleCount": meshes.reduce(0) { $0 + $1.indices.count / 3 },
                ]
            }
        } catch let error as AdaScriptError {
            throw Failure("Generator script failed: \(error.description)")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        let assets = try assetsURL()
        summary["path"] = destination
        summary["assetReference"] = "@res://" + url.pathComponents.dropFirst(assets.pathComponents.count).joined(separator: "/")
        summary["bytes"] = data.count
        summary["requiresRebuild"] = true
        return summary
    }

    private func assetsURL() throws -> URL {
        let project = try ProjectSystem.loadProject(at: projectURL)
        return projectURL.appendingPathComponent(project.paths.assets ?? "Assets").resolvingSymlinksInPath().standardizedFileURL
    }

    private func destinationURL(_ path: String, extension ext: String) throws -> URL {
        guard !path.hasPrefix("/"), !path.hasPrefix("~") else { throw Failure("Use a project-relative Assets path.") }
        let url = projectURL.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        let root = try assetsURL()
        guard url.pathComponents.starts(with: root.pathComponents), url.pathComponents.count > root.pathComponents.count,
            url.pathExtension.lowercased() == ext
        else { throw Failure("Destination must be a .\(ext) path inside Assets.") }
        return url
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
