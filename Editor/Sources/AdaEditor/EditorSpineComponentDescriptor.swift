import AdaEngine
import AdaSpine
import Foundation

extension EditorComponentRegistry {
    static let spineSourceDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.spineSource,
        displayName: "Spine 2D", category: "2D",
        description: "Spine 4.2 skeleton, skins, animation playback and bone overlay.",
        requiredComponentTypeNames: [EditorBuiltInComponentType.transform],
        fields: [
            EditorComponentField(key: "source", label: "Skeleton", kind: .assetReference),
            EditorComponentField(key: "animation", label: "Animation", kind: .string),
            EditorComponentField(key: "skin", label: "Skin", kind: .string),
            EditorComponentField(key: "autoplay", label: "Play animation", kind: .bool),
            EditorComponentField(key: "repeats", label: "Loop", kind: .bool),
            EditorComponentField(key: "speed", label: "Speed", kind: .float),
            EditorComponentField(key: "showBones", label: "Show bones", kind: .bool),
        ],
        makeDefaultPayload: { ["source": .string(""), "animation": .string(""), "skin": .string(""),
                               "autoplay": .bool(true), "repeats": .bool(true), "speed": .double(1), "showBones": .bool(true)] },
        decode: { payload in
            SpineSource(source: payload["source"]?.stringValue ?? "", animation: payload["animation"]?.stringValue ?? "",
                        skin: payload["skin"]?.stringValue ?? "", autoplay: payload["autoplay"]?.boolValue ?? true,
                        repeats: payload["repeats"]?.boolValue ?? true, speed: Float(payload["speed"]?.doubleValue ?? 1),
                        showBones: payload["showBones"]?.boolValue ?? true)
        }
    )
}

enum EditorSpineResource {
    static let extensions: Set<String> = ["skel", "spine"]

    static func resolve(_ reference: String, sourceURL: URL?, resourceRootURL: URL?) throws -> URL {
        let url: URL
        if reference.hasPrefix("@res://"), let resourceRootURL {
            url = resourceRootURL.appendingPathComponent(String(reference.dropFirst(7)))
        } else if let sourceURL {
            url = URL(fileURLWithPath: reference, relativeTo: sourceURL.deletingLastPathComponent())
        } else { throw AssetError.message("Unable to resolve Spine skeleton '\(reference)'.") }
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        if let resourceRootURL {
            let root = resourceRootURL.resolvingSymlinksInPath().standardizedFileURL
            guard resolved.path.hasPrefix(root.path + "/") else { throw AssetError.message("Spine skeleton must be inside project assets.") }
        }
        guard extensions.contains(resolved.pathExtension.lowercased()), FileManager.default.fileExists(atPath: resolved.path) else {
            throw AssetError.message("Spine skeleton is missing: \(reference)")
        }
        return resolved
    }
}
