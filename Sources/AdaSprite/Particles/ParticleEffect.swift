import AdaAssets
import AdaRender
import Foundation

/// Immutable authored effect and shared texture handles. Every emitter owns its playback state.
public struct ParticleEffect: Asset {
    public let descriptor: ParticleEffectDescriptor
    public let textures: [AssetHandle<Texture2D>?]
    public var assetMetaInfo: AssetMetaInfo?

    public init(_ descriptor: ParticleEffectDescriptor, textures: [AssetHandle<Texture2D>?] = []) throws {
        try descriptor.validate()
        guard textures.isEmpty || textures.count == descriptor.emitters.count else {
            throw ParticleEffectError.invalid("Texture count must match emitter count.")
        }
        self.descriptor = descriptor
        self.textures = textures
    }

    public init(from decoder: any AssetDecoder) async throws {
        let descriptor = try decoder.decode(ParticleEffectDescriptor.self)
        var textures: [AssetHandle<Texture2D>?] = []
        for emitter in descriptor.emitters {
            guard !emitter.texture.isEmpty else {
                textures.append(nil)
                continue
            }
            let path = emitter.texture.hasPrefix("@") || emitter.texture.hasPrefix("/")
                ? emitter.texture
                : URL(fileURLWithPath: emitter.texture, relativeTo: decoder.assetMeta.filePath.deletingLastPathComponent()).standardizedFileURL.path
            textures.append(try await AssetsManager.load(Texture2D.self, at: path, handleChanges: true))
        }
        try self.init(descriptor, textures: textures)
    }

    public func encodeContents(with encoder: any AssetEncoder) async throws {
        try encoder.encode(descriptor)
    }

    public static func extensions() -> [String] { ["particles"] }
}
