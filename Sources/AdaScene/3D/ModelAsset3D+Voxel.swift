//
//  ModelAsset3D+Voxel.swift
//  AdaEngine
//

import AdaAssets
@_spi(Internal) import AdaRender
import Foundation

extension ModelAsset3D {
    /// The data a model asset is made of, produced by importers.
    struct Contents {
        var nodes: [Node]
        var meshes: [Mesh]
        var materials: [Material]
        var scenes: [[Int]]
        var timeline: VoxelTimeline?
    }

    /// Imports a MagicaVoxel (`.vox`) file with default options.
    static func loadVoxelContents(url: URL) async throws -> Contents {
        let file = try await VOXLoader().load(url: url)
        return makeVoxelContents(file: file, options: VoxelImportOptions())
    }

    /// Converts a parsed MagicaVoxel scene to model contents, creating GPU meshes on the current render device.
    static func makeVoxelContents(file: VOXFile, options: VoxelImportOptions) -> Contents {
        let device = unsafe RenderEngine.shared.renderDevice
        let result = VoxelSceneBuilder.build(file: file, options: options)
        let meshes = result.meshes.map { Mesh.generate(from: [$0], renderDevice: device) }
        let nodes = result.nodes.map {
            Node(name: $0.name, transform: $0.transform, meshIndex: $0.meshIndex, children: $0.children, voxelAnimation: $0.animation)
        }
        let lastFrame = result.nodes.compactMap { $0.animation?.lastFrame }.max()
        // Palette colors live in vertex colors. PBRMaterial defaults to fully metallic, which makes voxels mirror-like.
        let material = PBRMaterial()
        material.metallicFactor = 0
        material.roughnessFactor = 0.85
        return Contents(
            nodes: nodes,
            meshes: meshes,
            materials: [material],
            scenes: [[result.rootNodeIndex]],
            timeline: lastFrame.map { VoxelTimeline(framesPerSecond: options.framesPerSecond, frameCount: $0 + 1) }
        )
    }

    /// Creates a model from a parsed MagicaVoxel file.
    public convenience init(voxelFile: VOXFile, options: VoxelImportOptions = VoxelImportOptions()) {
        let contents = Self.makeVoxelContents(file: voxelFile, options: options)
        self.init(
            nodes: contents.nodes,
            meshes: contents.meshes,
            materials: contents.materials,
            scenes: contents.scenes,
            defaultScene: 0
        )
        self.voxelTimeline = contents.timeline
    }
}
