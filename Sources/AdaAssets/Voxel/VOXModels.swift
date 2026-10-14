//
//  VOXModels.swift
//  AdaEngine
//

import Foundation

/// An RGBA color stored in a MagicaVoxel palette.
public struct VOXColor: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// A single voxel with a 1-based palette index.
public struct VOXVoxel: Hashable, Sendable {
    public var x: UInt8
    public var y: UInt8
    public var z: UInt8
    /// Palette index in `1...255`. Index `n` maps to `VOXPalette.colors[n - 1]`.
    public var colorIndex: UInt8

    public init(x: UInt8, y: UInt8, z: UInt8, colorIndex: UInt8) {
        self.x = x
        self.y = y
        self.z = z
        self.colorIndex = colorIndex
    }
}

/// A sparse voxel grid in MagicaVoxel space (right-handed, Z up).
public struct VOXModel: Hashable, Sendable {
    public var sizeX: Int
    public var sizeY: Int
    public var sizeZ: Int
    public var voxels: [VOXVoxel]

    public init(sizeX: Int, sizeY: Int, sizeZ: Int, voxels: [VOXVoxel]) {
        self.sizeX = sizeX
        self.sizeY = sizeY
        self.sizeZ = sizeZ
        self.voxels = voxels
    }
}

/// A 256-entry MagicaVoxel palette.
public struct VOXPalette: Hashable, Sendable {
    public static let count = 256

    /// Exactly 256 colors. Voxel color index `n` maps to `colors[n - 1]`.
    public var colors: [VOXColor]

    public init(colors: [VOXColor]) {
        self.colors = colors
    }

    /// Fallback palette used when a file has no `RGBA` chunk: a grayscale ramp.
    public static var fallback: VOXPalette {
        VOXPalette(
            colors: (0..<count).map { index in
                let value = UInt8(truncatingIfNeeded: index)
                return VOXColor(red: value, green: value, blue: value)
            }
        )
    }

    /// Returns the color for a 1-based voxel color index.
    public func color(forIndex index: UInt8) -> VOXColor? {
        guard index >= 1, Int(index) <= colors.count else {
            return nil
        }
        return colors[Int(index) - 1]
    }
}

/// A MagicaVoxel material description (`MATL` chunk). Property values are kept as parsed strings keyed by name.
public struct VOXMaterial: Hashable, Sendable {
    /// 1-based palette index this material applies to.
    public var paletteIndex: Int
    public var properties: [String: String]

    public init(paletteIndex: Int, properties: [String: String]) {
        self.paletteIndex = paletteIndex
        self.properties = properties
    }

    /// Material type: `_diffuse`, `_metal`, `_glass` or `_emit`.
    public var type: String? { properties["_type"] }

    public func number(_ key: String) -> Float? {
        properties[key].flatMap { Float($0) }
    }
}

/// A scene layer (`LAYR` chunk).
public struct VOXLayer: Hashable, Sendable {
    public var id: Int
    public var name: String?
    public var isHidden: Bool

    public init(id: Int, name: String?, isHidden: Bool) {
        self.id = id
        self.name = name
        self.isHidden = isHidden
    }
}

/// A signed axis permutation used as the rotation of a transform frame.
public struct VOXRotation: Hashable, Sendable {
    /// Rows of the 3×3 matrix. Each row has exactly one non-zero entry of ±1.
    public var row0: SIMD3<Int8>
    public var row1: SIMD3<Int8>
    public var row2: SIMD3<Int8>

    public static let identity = VOXRotation(
        row0: SIMD3(1, 0, 0),
        row1: SIMD3(0, 1, 0),
        row2: SIMD3(0, 0, 1)
    )

    public init(row0: SIMD3<Int8>, row1: SIMD3<Int8>, row2: SIMD3<Int8>) {
        self.row0 = row0
        self.row1 = row1
        self.row2 = row2
    }

    /// Decodes the packed byte stored in the `_r` attribute.
    ///
    /// Bits 0-1 and 2-3 hold the column index of the non-zero entry in the first and second row,
    /// the third row takes the remaining column. Bits 4, 5 and 6 are the sign flags of rows 0, 1 and 2.
    public init?(packed: UInt8) {
        let index0 = Int(packed & 0b11)
        let index1 = Int((packed >> 2) & 0b11)
        guard index0 < 3, index1 < 3, index0 != index1 else {
            return nil
        }
        let index2 = 3 - index0 - index1

        func row(index: Int, negative: Bool) -> SIMD3<Int8> {
            var value = SIMD3<Int8>(repeating: 0)
            value[index] = negative ? -1 : 1
            return value
        }

        self.init(
            row0: row(index: index0, negative: packed & 0b0001_0000 != 0),
            row1: row(index: index1, negative: packed & 0b0010_0000 != 0),
            row2: row(index: index2, negative: packed & 0b0100_0000 != 0)
        )
    }

    /// Rotates an integer vector by this matrix.
    public func apply(x: Int, y: Int, z: Int) -> SIMD3<Int> {
        let vector = SIMD3<Int>(x, y, z)
        func dot(_ row: SIMD3<Int8>) -> Int {
            Int(row.x) * vector.x + Int(row.y) * vector.y + Int(row.z) * vector.z
        }
        return SIMD3(dot(row0), dot(row1), dot(row2))
    }
}

/// One keyframe of a transform node.
public struct VOXTransformFrame: Hashable, Sendable {
    public var rotation: VOXRotation
    /// Translation in voxels.
    public var translation: SIMD3<Int>
    /// Animation frame index (`_f`), `nil` when the frame is not keyed.
    public var frameIndex: Int?

    public init(rotation: VOXRotation = .identity, translation: SIMD3<Int> = .zero, frameIndex: Int? = nil) {
        self.rotation = rotation
        self.translation = translation
        self.frameIndex = frameIndex
    }
}

/// A transform node (`nTRN`) with at least one frame.
public struct VOXTransformNode: Hashable, Sendable {
    public var id: Int
    public var name: String?
    public var isHidden: Bool
    public var childID: Int
    public var layerID: Int
    public var frames: [VOXTransformFrame]

    public init(
        id: Int,
        name: String? = nil,
        isHidden: Bool = false,
        childID: Int,
        layerID: Int = -1,
        frames: [VOXTransformFrame] = [VOXTransformFrame()]
    ) {
        self.id = id
        self.name = name
        self.isHidden = isHidden
        self.childID = childID
        self.layerID = layerID
        self.frames = frames
    }

    /// `true` when the node has more than one keyframe.
    public var isAnimated: Bool { frames.count > 1 }
}

/// A group node (`nGRP`).
public struct VOXGroupNode: Hashable, Sendable {
    public var id: Int
    public var childIDs: [Int]

    public init(id: Int, childIDs: [Int]) {
        self.id = id
        self.childIDs = childIDs
    }
}

/// A shape node (`nSHP`) referencing models by index into `VOXFile.models`.
public struct VOXShapeNode: Hashable, Sendable {
    public struct ModelReference: Hashable, Sendable {
        public var modelIndex: Int
        /// Animation frame index (`_f`), `nil` when the reference is not keyed.
        public var frameIndex: Int?

        public init(modelIndex: Int, frameIndex: Int? = nil) {
            self.modelIndex = modelIndex
            self.frameIndex = frameIndex
        }
    }

    public var id: Int
    public var models: [ModelReference]

    public init(id: Int, models: [ModelReference]) {
        self.id = id
        self.models = models
    }

    /// `true` when the node switches between several models over time.
    public var isAnimated: Bool { models.count > 1 }
}

/// A node of the MagicaVoxel scene graph.
public enum VOXNode: Hashable, Sendable {
    case transform(VOXTransformNode)
    case group(VOXGroupNode)
    case shape(VOXShapeNode)

    public var id: Int {
        switch self {
        case .transform(let node): node.id
        case .group(let node): node.id
        case .shape(let node): node.id
        }
    }
}

/// A parsed MagicaVoxel file in raw MagicaVoxel space.
public struct VOXFile: Sendable {
    public var version: Int
    public var models: [VOXModel]
    public var palette: VOXPalette
    /// `true` when the file contained an `RGBA` chunk; otherwise `palette` is the grayscale fallback.
    public var hasCustomPalette: Bool
    public var materials: [VOXMaterial]
    public var layers: [VOXLayer]
    /// Scene graph nodes by id. Empty for files older than version 150.
    public var nodes: [Int: VOXNode]

    public init(
        version: Int = 150,
        models: [VOXModel],
        palette: VOXPalette = .fallback,
        hasCustomPalette: Bool = false,
        materials: [VOXMaterial] = [],
        layers: [VOXLayer] = [],
        nodes: [Int: VOXNode] = [:]
    ) {
        self.version = version
        self.models = models
        self.palette = palette
        self.hasCustomPalette = hasCustomPalette
        self.materials = materials
        self.layers = layers
        self.nodes = nodes
    }

    /// The root of the scene graph, the transform node with id `0` when present.
    public var rootNode: VOXNode? { nodes[0] }
}
