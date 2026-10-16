//
//  VoxelImportSettings.swift
//  AdaEngine
//

import AdaAssets
import Foundation

/// Per-model import settings for MagicaVoxel (`.vox`) files, stored with a ``Model3DSource``.
///
/// Settings travel to the importer as an asset query, `@res://castle.vox#voxelSize=0.05&mergeStatic=1&fps=24`, the same
/// way other assets receive options. Only values that differ from the defaults are written, and unknown or invalid
/// values are ignored.
public struct VoxelImportSettings: Codable, Equatable, Hashable, Sendable {
    public static let defaultVoxelSize: Float = 0.1
    public static let defaultFramesPerSecond: Double = 30

    /// Edge length of one voxel in world units.
    public var voxelSize: Float
    /// Merges static subtrees into one mesh. See ``VoxelImportOptions/mergeStatic``.
    public var mergeStatic: Bool
    /// Playback rate of MagicaVoxel animation frames.
    public var framesPerSecond: Double

    public init(
        voxelSize: Float = VoxelImportSettings.defaultVoxelSize,
        mergeStatic: Bool = false,
        framesPerSecond: Double = VoxelImportSettings.defaultFramesPerSecond
    ) {
        self.voxelSize = voxelSize
        self.mergeStatic = mergeStatic
        self.framesPerSecond = framesPerSecond
    }

    /// Settings that equal the importer's defaults add nothing to the asset path.
    public var isDefault: Bool {
        self == VoxelImportSettings()
    }

    /// The import options these settings describe. Invalid values fall back to the defaults.
    public var options: VoxelImportOptions {
        VoxelImportOptions(
            voxelSize: Self.isValid(voxelSize: voxelSize) ? voxelSize : Self.defaultVoxelSize,
            mergeStatic: mergeStatic,
            framesPerSecond: Self.isValid(framesPerSecond: framesPerSecond) ? framesPerSecond : Self.defaultFramesPerSecond
        )
    }

    /// The query (without `#`) for the settings that differ from the defaults, or an empty string.
    public var assetQuery: String {
        var pairs: [String] = []
        if Self.isValid(voxelSize: voxelSize), voxelSize != Self.defaultVoxelSize {
            pairs.append("voxelSize=\(voxelSize)")
        }
        if mergeStatic {
            pairs.append("mergeStatic=1")
        }
        if Self.isValid(framesPerSecond: framesPerSecond), framesPerSecond != Self.defaultFramesPerSecond {
            pairs.append("fps=\(framesPerSecond)")
        }
        return pairs.joined(separator: "&")
    }

    /// Parses an asset query such as `voxelSize=0.05&mergeStatic=1`.
    public init(query: String) {
        self.init(
            pairs: query.split(separator: "&").map { pair in
                let parts = pair.split(separator: "=", maxSplits: 1)
                return (String(parts[0]), parts.count == 2 ? String(parts[1]) : nil)
            }
        )
    }

    /// Reads the settings from the query parameters an importer receives.
    public init(queryParams: [AssetQuery]) {
        self.init(pairs: queryParams.map { ($0.name, $0.value) })
    }

    private init(pairs: [(name: String, value: String?)]) {
        self.init()
        for (name, value) in pairs {
            switch name {
            case "voxelSize":
                if let parsed = value.flatMap(Float.init), Self.isValid(voxelSize: parsed) {
                    voxelSize = parsed
                }
            case "mergeStatic":
                mergeStatic = value == nil || value == "1" || value == "true"
            case "fps":
                if let parsed = value.flatMap(Double.init), Self.isValid(framesPerSecond: parsed) {
                    framesPerSecond = parsed
                }
            default:
                break
            }
        }
    }

    private static func isValid(voxelSize: Float) -> Bool {
        voxelSize.isFinite && voxelSize > 0 && voxelSize <= 1000
    }

    private static func isValid(framesPerSecond: Double) -> Bool {
        framesPerSecond.isFinite && framesPerSecond > 0 && framesPerSecond <= 1000
    }
}
