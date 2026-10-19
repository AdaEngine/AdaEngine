import AdaAssets
import AdaRender
import Foundation
import Math
import Synchronization

public enum SpriteAnimationError: Error, Equatable, LocalizedError {
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

/// Authored contents of a `.spriteanim` resource.
public struct SpriteAnimationSetDescriptor: Codable, Sendable, Equatable {
    public enum Filter: String, Codable, Sendable, CaseIterable {
        case nearest
        case linear
    }

    public var version: Int
    /// Image path. Relative paths resolve next to the resource file.
    public var image: String
    /// Grid cell size for frames that use `atlasCoordinates`. Defaults to the whole image.
    public var cellSize: SizeInt?
    public var margin: SizeInt?
    public var offset: SizeInt?
    public var filter: Filter
    public var clips: [SpriteAnimationClip]

    public init(
        image: String,
        cellSize: SizeInt? = nil,
        margin: SizeInt? = nil,
        offset: SizeInt? = nil,
        filter: Filter = .linear,
        clips: [SpriteAnimationClip] = []
    ) {
        self.version = 1
        self.image = image
        self.cellSize = cellSize
        self.margin = margin
        self.offset = offset
        self.filter = filter
        self.clips = clips
    }

    private enum CodingKeys: CodingKey { case version, image, cellSize, margin, offset, filter, clips }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.image = try values.decode(String.self, forKey: .image)
        self.cellSize = try values.decodeIfPresent(SizeInt.self, forKey: .cellSize)
        self.margin = try values.decodeIfPresent(SizeInt.self, forKey: .margin)
        self.offset = try values.decodeIfPresent(SizeInt.self, forKey: .offset)
        self.filter = try values.decodeIfPresent(Filter.self, forKey: .filter) ?? .linear
        self.clips = try values.decodeIfPresent([SpriteAnimationClip].self, forKey: .clips) ?? []
    }

    /// Rejects shapes that could never play: unnamed or duplicate clips and frames without exactly one pixel source.
    /// - Parameter requiresImage: Authoring tools pass false while a new resource is still waiting for its image.
    public func validate(requiresImage: Bool = true) throws {
        guard !requiresImage || !image.isEmpty else { throw SpriteAnimationError.invalid("Image path is empty.") }
        var names: Set<String> = []
        for clip in clips {
            guard !clip.name.isEmpty else { throw SpriteAnimationError.invalid("A clip has no name.") }
            guard names.insert(clip.name).inserted else { throw SpriteAnimationError.invalid("Clip '\(clip.name)' is declared twice.") }
            guard clip.framesPerSecond.isFinite, clip.framesPerSecond > 0 else {
                throw SpriteAnimationError.invalid("Clip '\(clip.name)' needs a positive framesPerSecond.")
            }
            for (index, frame) in clip.frames.enumerated() {
                guard (frame.atlasCoordinates == nil) != (frame.region == nil) else {
                    throw SpriteAnimationError.invalid("Frame \(index) of '\(clip.name)' needs exactly one of atlasCoordinates and region.")
                }
                guard frame.duration.isFinite, frame.duration >= 0 else {
                    throw SpriteAnimationError.invalid("Frame \(index) of '\(clip.name)' has an invalid duration.")
                }
            }
        }
    }
}

/// Image plus named clips, shared by every ``SpriteAnimator`` that references it.
public final class SpriteAnimationSet: Asset, @unchecked Sendable {
    private enum SliceKey: Hashable {
        case cell(PointInt)
        case region(RectInt)
    }

    public private(set) var clips: [SpriteAnimationClip]
    public let atlas: TextureAtlas
    /// Present for sets loaded from or built for a `.spriteanim` resource; required to save.
    public private(set) var descriptor: SpriteAnimationSetDescriptor?
    public var assetMetaInfo: AssetMetaInfo?

    private let slices = Mutex<[SliceKey: TextureAtlas.Slice]>([:])

    /// Wraps an existing atlas, for sets built in code.
    public init(atlas: TextureAtlas, clips: [SpriteAnimationClip]) {
        self.atlas = atlas
        self.clips = clips
    }

    public init(descriptor: SpriteAnimationSetDescriptor, image: Image) throws {
        try descriptor.validate()
        var image = image
        let sampler: SamplerMinMagFilter = descriptor.filter == .nearest ? .nearest : .linear
        image.samplerDescription.magFilter = sampler
        image.samplerDescription.minFilter = sampler
        let cell = descriptor.cellSize ?? SizeInt(width: image.width, height: image.height)
        self.atlas = TextureAtlas(from: image, size: cell, margin: descriptor.margin ?? .zero, offset: descriptor.offset ?? .zero)
        self.clips = descriptor.clips
        self.descriptor = descriptor
    }

    public required convenience init(from assetDecoder: any AssetDecoder) async throws {
        let descriptor = try assetDecoder.decode(SpriteAnimationSetDescriptor.self)
        try descriptor.validate()
        let base = assetDecoder.assetMeta.filePath.deletingLastPathComponent()
        let path = Self.isAbsolute(descriptor.image) ? descriptor.image : base.appendingPathComponent(descriptor.image).standardizedFileURL.path
        let handle = try await AssetsManager.load(Image.self, at: path)
        guard let image = handle.asset else {
            throw AssetDecodingError.decodingProblem("SpriteAnimationSet: image at \(descriptor.image) was not loaded.")
        }
        try self.init(descriptor: descriptor, image: image)
    }

    public func encodeContents(with assetEncoder: any AssetEncoder) async throws {
        guard let descriptor else {
            throw AssetDecodingError.decodingProblem("SpriteAnimationSet: only sets created from a descriptor can be encoded.")
        }
        try assetEncoder.encode(descriptor)
    }

    public static func extensions() -> [String] { ["spriteanim"] }

    public func clip(named name: String) -> SpriteAnimationClip? {
        clips.first { $0.name == name }
    }

    /// The shared texture slice for a frame, or nil when its cell or region lies outside the image.
    public func texture(for frame: SpriteAnimationFrame) -> Texture2D? {
        let key: SliceKey
        if let region = frame.region {
            key = .region(region)
        } else if let cell = frame.atlasCoordinates {
            key = .cell(cell)
        } else {
            return nil
        }
        return slices.withLock { cache -> TextureAtlas.Slice? in
            if let cached = cache[key] { return cached }
            let slice: TextureAtlas.Slice?
            switch key {
            case .region(let region): slice = atlas.textureSlice(in: region)
            case .cell(let cell): slice = atlas.textureSlice(at: cell)
            }
            if let slice { cache[key] = slice }
            return slice
        }
    }

    private static func isAbsolute(_ path: String) -> Bool {
        path.hasPrefix("@res://") || path.hasPrefix("file://") || path.hasPrefix("/") || path.hasPrefix("\\\\")
            || (path.count >= 3 && path.dropFirst().hasPrefix(":") && (path.dropFirst(2).hasPrefix("/") || path.dropFirst(2).hasPrefix("\\")))
    }
}
