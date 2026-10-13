@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorComponentRegistry {
    static let particleEmitterDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.particleEmitter,
        displayName: "Particle Emitter",
        category: "2D",
        description: "Plays a reusable particle effect. Stop emission, pause or increment Restart Count to replay.",
        requiredComponentTypeNames: [EditorBuiltInComponentType.transform],
        fields: [
            EditorComponentField(key: "effect", label: "Particle Effect", kind: .assetReference),
            EditorComponentField(key: "isEmitting", label: "Emitting", kind: .bool),
            EditorComponentField(key: "isPaused", label: "Paused", kind: .bool),
            EditorComponentField(key: "restartCount", label: "Restart Count", kind: .int),
        ],
        makeDefaultPayload: { ["effect": .string(""), "isEmitting": .bool(true), "isPaused": .bool(false), "restartCount": .int(0)] },
        decode: { payload in
            var handle: AssetHandle<ParticleEffect>?
            if let path = payload["effect"]?.stringValue, !path.isEmpty {
                #if WASM
                    throw AssetError.message("Particle scene resources must be preloaded on WebAssembly.")
                #else
                    handle = try AssetsManager.loadErasedSync(ParticleEffect.self, at: path, handleChanges: true) as? AssetHandle<ParticleEffect>
                    guard handle != nil else { throw AssetError.message("Particle effect did not load.") }
                #endif
            }
            return ParticleEmitter(
                effect: handle,
                isEmitting: payload["isEmitting"]?.boolValue ?? true,
                isPaused: payload["isPaused"]?.boolValue ?? false,
                restartCount: payload["restartCount"]?.doubleValue.map(Int.init) ?? 0
            )
        }
    )
}
