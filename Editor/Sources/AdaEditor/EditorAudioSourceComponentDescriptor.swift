@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorComponentRegistry {
    static let audioSourceDescriptor: EditorComponentDescriptor = {
        var volume = EditorComponentField(key: "volume", label: "Volume (0-1)", kind: .float)
        volume.defaultValue = .double(1)
        volume.minimumValue = 0
        return EditorComponentDescriptor(
            typeName: EditorBuiltInComponentType.audioSource,
            displayName: "Audio Source",
            category: "Audio",
            description: "Plays a WAV, MP3 or FLAC sound from the entity's position. Scripts set play or stop to trigger it.",
            requiredComponentTypeNames: [EditorBuiltInComponentType.transform],
            fields: [
                EditorComponentField(key: "source", label: "Sound", kind: .assetReference),
                volume,
                EditorComponentField(key: "loops", label: "Loop", kind: .bool),
                EditorComponentField(key: "autoplay", label: "Play on start", kind: .bool),
            ],
            makeDefaultPayload: { ["source": .string(""), "volume": .double(1), "loops": .bool(false), "autoplay": .bool(false)] },
            decode: { payload in
                AudioSource(
                    source: payload["source"]?.stringValue ?? "",
                    volume: payload["volume"]?.doubleValue.map { Float(max(0, min($0, 1))) } ?? 1,
                    loops: payload["loops"]?.boolValue ?? false,
                    autoplay: payload["autoplay"]?.boolValue ?? false,
                    play: payload["play"]?.boolValue ?? false,
                    stop: payload["stop"]?.boolValue ?? false
                )
            }
        )
    }()
}
