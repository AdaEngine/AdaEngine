@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorComponentRegistry {
    static let spriteAnimatorDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.spriteAnimator,
        displayName: "Sprite Animator",
        category: "2D",
        description: "Plays a clip of a Sprite Animation resource on this entity's Sprite. Change Clip to switch, or increment Restart Count to replay.",
        requiredComponentTypeNames: [EditorBuiltInComponentType.sprite],
        fields: [
            EditorComponentField(key: "animations", label: "Sprite Animation", kind: .assetReference),
            EditorComponentField(key: "currentClip", label: "Clip", kind: .string),
            EditorComponentField(key: "isPlaying", label: "Playing", kind: .bool),
            EditorComponentField(key: "speed", label: "Speed", kind: .float),
            EditorComponentField(key: "restartCount", label: "Restart Count", kind: .int),
        ],
        makeDefaultPayload: {
            ["animations": .string(""), "currentClip": .string(""), "isPlaying": .bool(true), "speed": .double(1), "restartCount": .int(0)]
        },
        decode: { payload in
            var handle: AssetHandle<SpriteAnimationSet>?
            if let path = payload["animations"]?.stringValue, !path.isEmpty {
                #if WASM
                    throw AssetError.message("Sprite animation scene resources must be preloaded on WebAssembly.")
                #else
                    handle = try AssetsManager.loadErasedSync(SpriteAnimationSet.self, at: path, handleChanges: true) as? AssetHandle<SpriteAnimationSet>
                    guard handle != nil else { throw AssetError.message("Sprite animation did not load.") }
                #endif
            }
            let clip = payload["currentClip"]?.stringValue
            return SpriteAnimator(
                animations: handle,
                initialClip: clip?.isEmpty == false ? clip : nil,
                isPlaying: payload["isPlaying"]?.boolValue ?? true,
                speed: payload["speed"]?.doubleValue.map(Float.init) ?? 1,
                restartCount: payload["restartCount"]?.doubleValue.map(Int.init) ?? 0
            )
        }
    )
}
