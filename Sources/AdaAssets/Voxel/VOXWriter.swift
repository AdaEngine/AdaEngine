//
//  VOXWriter.swift
//  AdaEngine
//

import Foundation

public enum VOXWritingError: Error, Equatable, Sendable {
    /// A model dimension is outside `1...256`.
    case invalidSize(x: Int, y: Int, z: Int)
    /// A voxel lies outside its model bounds or uses color index `0`.
    case invalidVoxel(index: Int)
    case invalidPalette
}

/// Encodes a single-model MagicaVoxel (version 150) file with a custom palette.
///
/// The output is the inverse of ``VOXLoader`` and can be opened in MagicaVoxel.
public struct VOXWriter: Sendable {
    public static let maximumDimension = 256

    public init() {}

    public func encode(model: VOXModel, palette: VOXPalette) throws -> Data {
        let limit = Self.maximumDimension
        guard (1...limit).contains(model.sizeX), (1...limit).contains(model.sizeY), (1...limit).contains(model.sizeZ) else {
            throw VOXWritingError.invalidSize(x: model.sizeX, y: model.sizeY, z: model.sizeZ)
        }
        guard palette.colors.count == VOXPalette.count else {
            throw VOXWritingError.invalidPalette
        }
        for (index, voxel) in model.voxels.enumerated() {
            guard Int(voxel.x) < model.sizeX, Int(voxel.y) < model.sizeY, Int(voxel.z) < model.sizeZ, voxel.colorIndex >= 1 else {
                throw VOXWritingError.invalidVoxel(index: index)
            }
        }

        var size = Data()
        size.appendInt32(model.sizeX)
        size.appendInt32(model.sizeY)
        size.appendInt32(model.sizeZ)

        var voxels = Data(capacity: 4 + model.voxels.count * 4)
        voxels.appendInt32(model.voxels.count)
        for voxel in model.voxels {
            voxels.append(contentsOf: [voxel.x, voxel.y, voxel.z, voxel.colorIndex])
        }

        var colors = Data(capacity: VOXPalette.count * 4)
        for color in palette.colors {
            colors.append(contentsOf: [color.red, color.green, color.blue, color.alpha])
        }

        var children = Data()
        children.appendChunk("SIZE", content: size)
        children.appendChunk("XYZI", content: voxels)
        children.appendChunk("RGBA", content: colors)

        var file = Data("VOX ".utf8)
        file.appendInt32(150)
        file.appendChunk("MAIN", content: Data(), children: children)
        return file
    }
}

private extension Data {
    mutating func appendInt32(_ value: Int) {
        var little = Int32(truncatingIfNeeded: value).littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendChunk(_ id: String, content: Data, children: Data = Data()) {
        append(contentsOf: Array(id.utf8))
        appendInt32(content.count)
        appendInt32(children.count)
        append(content)
        append(children)
    }
}
