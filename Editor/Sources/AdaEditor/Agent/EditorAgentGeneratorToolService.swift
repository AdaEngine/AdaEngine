import AdaAssets
import AdaScripting
import Foundation
import MCP

/// Runs an agent-authored AdaScript generator in an isolated VM and saves the result as an asset:
/// `editor.voxel.generate` writes a MagicaVoxel `.vox`, `editor.model.generate` a binary glTF `.glb`,
/// `editor.audio.generate` a 16-bit PCM `.wav` and `editor.sprite.generate` a `.png`.
/// `editor.audio.inspect` measures an existing WAV file without any script.
@MainActor
struct EditorAgentGeneratorToolService {
    static let toolNames: Set<String> = ["editor.voxel.generate", "editor.model.generate", "editor.audio.generate", "editor.sprite.generate", "editor.audio.inspect"]

    private let projectURL: URL

    init(projectURL: URL) {
        self.projectURL = projectURL.resolvingSymlinksInPath().standardizedFileURL
    }

    func execute(name: String, arguments: [String: Value]) throws -> [String: Any] {
        guard Self.toolNames.contains(name) else { throw Failure("Unknown generator tool: \(name)") }
        if name == "editor.audio.inspect" { return try inspectAudio(arguments) }
        guard let source = arguments["source"]?.stringValue, !source.isEmpty else { throw Failure("Missing source.") }
        guard let destination = arguments["destination"]?.stringValue, !destination.isEmpty else { throw Failure("Missing destination.") }
        let (fileExtension, result) = try Self.generation(for: name)
        let url = try destinationURL(destination, extension: fileExtension)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw Failure("Destination exists: \(destination). Choose a new name; existing assets are preserved.")
        }
        let generated: (Data, [String: Any])
        do {
            generated = try result(source)
        } catch let error as AdaScriptError {
            throw Failure("Generator script failed: \(error.description)")
        }
        let data = generated.0
        var summary = generated.1
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        summary["path"] = destination
        summary["assetReference"] = try reference(url)
        summary["bytes"] = data.count
        summary["requiresRebuild"] = true
        return summary
    }

    // MARK: - Generators

    private typealias Generate = @MainActor (String) throws -> (Data, [String: Any])

    private static func generation(for name: String) throws -> (String, Generate) {
        switch name {
        case "editor.voxel.generate": ("vox", voxel)
        case "editor.model.generate": ("glb", model)
        case "editor.audio.generate": ("wav", sound)
        default: ("png", sprite)
        }
    }

    private static let voxel: Generate = { source in
        let result = try AdaScriptVoxelGenerator.generate(source: source)
        return (
            try VOXWriter().encode(model: result.model, palette: result.palette),
            [
                "size": [result.model.sizeX, result.model.sizeY, result.model.sizeZ],
                "voxelCount": result.model.voxels.count,
                "paletteIndicesUsed": Set(result.model.voxels.map(\.colorIndex)).sorted().map { Int($0) },
            ]
        )
    }

    private static let model: Generate = { source in
        let model = try AdaScriptModelGenerator.generate(source: source)
        let meshes = model.nodes.compactMap(\.mesh)
        return (
            try GLBWriter().encode(model),
            [
                "parts": model.nodes.map { node -> [String: Any] in
                    var part: [String: Any] = ["name": node.name, "hasMesh": node.mesh != nil]
                    if let parent = node.parent { part["parent"] = model.nodes[parent].name }
                    return part
                },
                "materials": model.materials.map(\.name),
                "vertexCount": meshes.reduce(0) { $0 + $1.positions.count },
                "triangleCount": meshes.reduce(0) { $0 + $1.indices.count / 3 },
            ]
        )
    }

    private static let sound: Generate = { source in
        let audio = try AdaScriptSoundGenerator.generate(source: source)
        return (try WAVWriter().encode(audio), report(AudioAnalyzer.analyze(audio)))
    }

    private static let sprite: Generate = { source in
        let canvas = try AdaScriptSpriteGenerator.generate(source: source).canvas
        return (
            try PNGWriter().encode(width: canvas.width, height: canvas.height, rgba: canvas.rgba()),
            [
                "size": [canvas.width, canvas.height],
                "opaquePixels": canvas.opaquePixelCount,
                "paletteIndicesUsed": canvas.usedColors.map { Int($0) },
                "hint": "Read it with editor.image.read to check how it looks. Use editor.tileset.create for a tile sheet or editor.atlas.pack for an atlas.",
            ]
        )
    }

    private static func report(_ report: AudioReport) -> [String: Any] {
        func rounded(_ value: Double, _ digits: Double = 100) -> Double { (value * digits).rounded() / digits }
        return [
            "durationSeconds": rounded(report.duration, 1000),
            "sampleRate": report.sampleRate,
            "channels": report.channels,
            "peak": rounded(Double(report.peak), 1000),
            "peakDBFS": rounded(Double(report.peakDecibels)),
            "rmsDBFS": rounded(Double(report.rmsDecibels)),
            "clippedSamples": report.clippedSamples,
            "dcOffset": rounded(Double(report.dcOffset), 10000),
            "leadingSilenceSeconds": rounded(report.leadingSilence, 1000),
            "trailingSilenceSeconds": rounded(report.trailingSilence, 1000),
            "dominantFrequencyHz": rounded(report.dominantFrequency, 1),
            "spectralCentroidHz": rounded(report.spectralCentroid, 1),
            "loudnessEnvelopeDBFS": report.envelope.map { rounded(Double($0), 10) },
        ]
    }

    private func inspectAudio(_ arguments: [String: Value]) throws -> [String: Any] {
        guard let path = arguments["path"]?.stringValue, !path.isEmpty else { throw Failure("Missing path.") }
        let url = try destinationURL(path, extension: "wav", mustExist: true)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? Int, size <= WAVReader.maximumBytes else { throw Failure("Audio file exceeds 64 MB.") }
        let audio: WAVAudio
        do {
            audio = try WAVReader().decode(Data(contentsOf: url))
        } catch let error as WAVError {
            throw Failure("Cannot read WAV file: \(error). Only PCM and float WAV files can be measured.")
        }
        var summary = Self.report(AudioAnalyzer.analyze(audio))
        summary["path"] = path
        summary["assetReference"] = try reference(url)
        return summary
    }

    // MARK: - Paths

    private func assetsURL() throws -> URL {
        let project = try ProjectSystem.loadProject(at: projectURL)
        return projectURL.appendingPathComponent(project.paths.assets ?? "Assets").resolvingSymlinksInPath().standardizedFileURL
    }

    private func reference(_ url: URL) throws -> String {
        "@res://" + url.pathComponents.dropFirst(try assetsURL().pathComponents.count).joined(separator: "/")
    }

    private func destinationURL(_ path: String, extension ext: String, mustExist: Bool = false) throws -> URL {
        guard !path.hasPrefix("/"), !path.hasPrefix("~") else { throw Failure("Use a project-relative Assets path.") }
        let url = projectURL.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        let root = try assetsURL()
        guard url.pathComponents.starts(with: root.pathComponents), url.pathComponents.count > root.pathComponents.count,
            url.pathExtension.lowercased() == ext
        else { throw Failure("Path must be a .\(ext) file inside Assets.") }
        if mustExist, !FileManager.default.fileExists(atPath: url.path) { throw Failure("No such file: \(path)") }
        return url
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
