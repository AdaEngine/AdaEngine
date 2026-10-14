//
//  VoxelImportOptions.swift
//  AdaEngine
//

import AdaRender

/// Options controlling how a MagicaVoxel scene becomes a ``ModelAsset3D``.
public struct VoxelImportOptions: Sendable {
    /// Edge length of one voxel in world units.
    public var voxelSize: Float
    /// Merges every subtree without animated transforms or animated shapes into a single mesh.
    ///
    /// Merging lowers the draw call count and removes hidden inner faces, but the merged parts
    /// are no longer addressable as separate entities.
    public var mergeStatic: Bool
    public var meshingStrategy: VoxelMeshingOptions.Strategy
    public var bakesAmbientOcclusion: Bool
    /// Playback rate of MagicaVoxel animation frames.
    public var framesPerSecond: Double

    /// The largest merged grid volume (in cells). Larger subtrees fall back to separate meshes.
    public var maximumMergedVolume: Int

    public init(
        voxelSize: Float = 0.1,
        mergeStatic: Bool = false,
        meshingStrategy: VoxelMeshingOptions.Strategy = .greedy,
        bakesAmbientOcclusion: Bool = true,
        framesPerSecond: Double = 30,
        maximumMergedVolume: Int = 64 * 1024 * 1024
    ) {
        self.framesPerSecond = framesPerSecond
        self.voxelSize = voxelSize
        self.mergeStatic = mergeStatic
        self.meshingStrategy = meshingStrategy
        self.bakesAmbientOcclusion = bakesAmbientOcclusion
        self.maximumMergedVolume = maximumMergedVolume
    }

    var meshingOptions: VoxelMeshingOptions {
        VoxelMeshingOptions(voxelSize: voxelSize, strategy: meshingStrategy, bakesAmbientOcclusion: bakesAmbientOcclusion)
    }
}

/// Animation timeline of an imported voxel scene.
public struct VoxelTimeline: Sendable, Equatable {
    public var framesPerSecond: Double
    /// Length of the timeline in frames.
    public var frameCount: Int

    public init(framesPerSecond: Double, frameCount: Int) {
        self.framesPerSecond = framesPerSecond
        self.frameCount = frameCount
    }
}
