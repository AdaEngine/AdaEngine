import AdaECS
@_spi(Internal) import AdaRender
import Math

/// Screen-space tiles that each carry a bit mask of the local lights reaching them.
///
/// The main pass evaluates only the lights set in the pixel's tile instead of every light in the frame. A light
/// reaches a tile when the screen-space bounds of its range sphere overlap it, so the mask is conservative and
/// never drops a light that could contribute: lights outside their range already contribute nothing, which keeps
/// the lit result identical to the flat loop.
enum LightTiles3DMath {
    /// Local lights per frame, one bit each in a 32-bit mask.
    static let maximumLights = 32
    /// Upper bound on tile count, set by the size of the GPU mask buffer.
    static let maximumTiles = 4096
    static let smallestTileSize = 32
    /// Nearest view depth a light sphere may reach before the whole screen counts as covered.
    private static let nearDepth: Float = 0.05

    struct Layout: Equatable {
        var tileSize: Int
        var columns: Int
        var rows: Int
        var count: Int { columns * rows }
    }

    /// The smallest power-of-two multiple of 32 pixels that keeps the tile count within `maximumTiles`.
    static func layout(width: Int, height: Int) -> Layout {
        var size = smallestTileSize
        func grid(_ size: Int) -> Layout {
            Layout(tileSize: size, columns: max(1, (width + size - 1) / size), rows: max(1, (height + size - 1) / size))
        }
        while grid(size).count > maximumTiles {
            size *= 2
        }
        return grid(size)
    }

    /// A mask with the first `count` lights set, used when tiles are not in play.
    static func allLights(_ count: Int) -> UInt32 {
        count >= maximumLights ? UInt32.max : (UInt32(1) << UInt32(max(count, 0))) - 1
    }

    /// One mask per tile for lights given as view-space sphere centers and ranges.
    ///
    /// `projection` maps view space to clip space (the one the main pass draws with) and `viewport` is the pixel
    /// rectangle it renders into.
    static func masks(
        spheres: [(center: Vector3, range: Float)],
        projection: Transform3D,
        viewport: Rect,
        layout: Layout
    ) -> [UInt32] {
        var masks = [UInt32](repeating: 0, count: layout.count)
        for (index, sphere) in spheres.prefix(maximumLights).enumerated() {
            let bit = UInt32(1) << UInt32(index)
            guard sphere.range > 0, sphere.center.z + sphere.range > 0 else {
                continue
            }
            guard let bounds = screenBounds(of: sphere, projection: projection, viewport: viewport) else {
                for tile in masks.indices { masks[tile] |= bit }
                continue
            }
            let size = Float(layout.tileSize)
            let firstColumn = max(0, Int((bounds.minX - 1) / size)), lastColumn = min(layout.columns - 1, Int((bounds.maxX + 1) / size))
            let firstRow = max(0, Int((bounds.minY - 1) / size)), lastRow = min(layout.rows - 1, Int((bounds.maxY + 1) / size))
            guard bounds.maxX >= 0, bounds.maxY >= 0, firstColumn <= lastColumn, firstRow <= lastRow else {
                continue
            }
            for row in firstRow...lastRow {
                for column in firstColumn...lastColumn {
                    masks[row * layout.columns + column] |= bit
                }
            }
        }
        return masks
    }

    /// Pixel bounds of the sphere's view-space bounding box, or `nil` when it may reach the camera plane and so
    /// can cover any pixel.
    private static func screenBounds(
        of sphere: (center: Vector3, range: Float),
        projection: Transform3D,
        viewport: Rect
    ) -> (minX: Float, minY: Float, maxX: Float, maxY: Float)? {
        guard sphere.center.z - sphere.range > nearDepth else {
            return nil
        }
        var bounds = (minX: Float.infinity, minY: Float.infinity, maxX: -Float.infinity, maxY: -Float.infinity)
        for corner in 0..<8 {
            let point = Vector4(
                sphere.center.x + (corner & 1 == 0 ? -sphere.range : sphere.range),
                sphere.center.y + (corner & 2 == 0 ? -sphere.range : sphere.range),
                sphere.center.z + (corner & 4 == 0 ? -sphere.range : sphere.range),
                1
            )
            let clip = projection * point
            guard clip.w > 0.0001 else {
                return nil
            }
            let pixelX = viewport.origin.x + (clip.x / clip.w * 0.5 + 0.5) * viewport.size.width
            let pixelY = viewport.origin.y + (0.5 - clip.y / clip.w * 0.5) * viewport.size.height
            bounds = (min(bounds.minX, pixelX), min(bounds.minY, pixelY), max(bounds.maxX, pixelX), max(bounds.maxY, pixelY))
        }
        return bounds
    }
}

/// Frame-buffered tile masks, one ring per camera.
struct LightTiles3DScratch: Resource {
    /// `uvec4` entries in the shader's mask array (`maximumTiles / 4`).
    static let maskVectors = LightTiles3DMath.maximumTiles / 4

    private var buffers: [Entity.ID: (buffers: [BufferData<SIMD4<UInt32>>], index: Int)] = [:]
    private let frames = max(1, unsafe RenderEngine.configurations.maxFramesInFlight)

    mutating func retainViews(_ views: [Entity.ID]) {
        for view in buffers.keys where !views.contains(view) { buffers.removeValue(forKey: view) }
    }

    mutating func write(view: Entity.ID, masks: [UInt32], device: RenderDevice) -> BufferData<SIMD4<UInt32>> {
        var entry = buffers.removeValue(forKey: view) ?? (
            (0..<frames).map { _ in BufferData(elements: [SIMD4<UInt32>](repeating: .zero, count: Self.maskVectors)) },
            0
        )
        entry.index = (entry.index + 1) % frames
        for vector in 0..<Self.maskVectors {
            var packed = SIMD4<UInt32>.zero
            for lane in 0..<4 {
                let tile = vector * 4 + lane
                packed[lane] = tile < masks.count ? masks[tile] : 0
            }
            entry.buffers[entry.index].elements[vector] = packed
        }
        entry.buffers[entry.index].write(to: device)
        let output = entry.buffers[entry.index]
        buffers[view] = entry
        return output
    }
}
