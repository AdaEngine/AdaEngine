import AdaAssets
import AdaRender
@_exported import AdaSpineRuntime
import Foundation

/// A Spine 4.2 export, its companion `.atlas`, and shared texture pages.
/// Each call to `makePlayer` creates independent playback state.
public struct SpineSkeleton: Asset {
    public let skeletonData: Data
    public let atlasText: String
    public let format: SpineSkeletonFormat
    public let scale: Float
    public let textures: [AssetHandle<Texture2D>]
    public let animationNames: [String]
    public let skinNames: [String]
    public var assetMetaInfo: AssetMetaInfo?

    public init(skeleton: Data, atlas: String, textures: [AssetHandle<Texture2D>], format: SpineSkeletonFormat = .json, scale: Float = 1) throws {
        let player = try SpineAnimationPlayer(skeleton: skeleton, atlas: atlas, format: format, scale: scale)
        guard textures.count == player.pageNames.count else {
            throw SpineError.invalidData("Provide one texture for every atlas page, in atlas order.")
        }
        self.skeletonData = skeleton
        self.atlasText = atlas
        self.textures = textures
        self.format = format
        self.scale = scale
        self.animationNames = player.animationNames
        self.skinNames = player.skinNames
    }

    /// Loads a JSON `.spine` (or explicitly requested `.json`) or binary `.skel` export.
    /// The atlas must have the same basename and reside beside the skeleton.
    public init(from decoder: any AssetDecoder) async throws {
        let url = decoder.assetMeta.filePath
        let atlasURL = url.deletingPathExtension().appendingPathExtension("atlas")
        let atlas = try await AssetsManager.load(SpineAtlasText.self, at: atlasURL.path)
        let format: SpineSkeletonFormat = url.pathExtension.lowercased() == "skel" ? .binary : .json
        let player = try SpineAnimationPlayer(skeleton: decoder.assetData, atlas: atlas.asset.text, format: format)
        var textures: [AssetHandle<Texture2D>] = []
        for page in player.pageNames {
            let path = atlasURL.deletingLastPathComponent().appendingPathComponent(page).path
            textures.append(try await AssetsManager.load(Texture2D.self, at: path))
        }
        try self.init(skeleton: decoder.assetData, atlas: atlas.asset.text, textures: textures, format: format)
    }

    public func makePlayer() throws -> SpineAnimationPlayer {
        try SpineAnimationPlayer(skeleton: skeletonData, atlas: atlasText, format: format, scale: scale)
    }

    public func encodeContents(with _: any AssetEncoder) throws {
        throw SpineError.invalidData("Export skeletons and atlases from Spine; runtime assets are read-only.")
    }

    public static func extensions() -> [String] { ["spine", "skel"] }
}

private struct SpineAtlasText: Asset {
    let text: String
    var assetMetaInfo: AssetMetaInfo?

    init(from decoder: any AssetDecoder) throws {
        guard let text = String(data: decoder.assetData, encoding: .utf8) else {
            throw SpineError.invalidData("The Spine atlas must contain UTF-8 text.")
        }
        self.text = text
    }

    func encodeContents(with _: any AssetEncoder) throws {
        throw SpineError.invalidData("Export the atlas from Spine.")
    }

    static func extensions() -> [String] { ["atlas"] }
}
