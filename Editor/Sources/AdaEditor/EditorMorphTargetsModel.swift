@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

/// Scene payloads keep morph weights as a structured map from target name to weight, the shape `Model3DSource.morphWeights` has.
enum EditorMorphWeightsPayload {
    static func decode(_ value: EditorSceneValue?) -> [String: Float] {
        guard case let .object(entries)? = value else {
            return [:]
        }
        var weights: [String: Float] = [:]
        for (name, entry) in entries {
            if let number = entry.doubleValue, number.isFinite { weights[name] = Float(number) }
        }
        return weights
    }

    static func encode(_ weights: [String: Float]) -> EditorSceneValue {
        .object(weights.mapValues { .double(Double($0)) })
    }
}

/// The named morph targets of a model and the weights an author has set for them.
@Observable
@MainActor
final class EditorMorphTargetsModel {
    struct Target: Equatable, Identifiable {
        let name: String
        /// The weight the file gives the target when nothing overrides it.
        let defaultWeight: Float
        var id: String { name }
    }

    /// The slider range. glTF weights are normally 0 to 1; the renderer extrapolates outside that.
    static let weightRange: ClosedRange<Float> = 0...1

    private(set) var targets: [Target] = []
    /// Targets of the model that have no name; they cannot be addressed from a scene.
    private(set) var unnamedTargetCount = 0
    private(set) var weights: [String: Float] = [:]

    func configure(asset: ModelAsset3D, authored: [String: Float]) {
        var seen: [String: Float] = [:]
        var order: [String] = []
        var unnamed = 0
        for (index, mesh) in asset.meshes.enumerated() where mesh.hasMorphTargets {
            let names = mesh.morphTargetNames
            let defaults = asset.meshMorphWeights.indices.contains(index) ? asset.meshMorphWeights[index] : []
            for target in 0..<mesh.morphTargetCount {
                guard names.indices.contains(target), !names[target].isEmpty else {
                    unnamed += 1
                    continue
                }
                if seen[names[target]] == nil {
                    order.append(names[target])
                    seen[names[target]] = defaults.indices.contains(target) ? defaults[target] : 0
                }
            }
        }
        targets = order.map { Target(name: $0, defaultWeight: seen[$0] ?? 0) }
        unnamedTargetCount = unnamed
        weights = authored.filter { entry in seen[entry.key] != nil }
    }

    /// The weight shown for a target: the authored one, else the file's default.
    func weight(of target: Target) -> Float {
        weights[target.name] ?? target.defaultWeight
    }

    func setWeight(_ value: Float, for target: Target) {
        guard value.isFinite else { return }
        let clamped = min(max(value, Self.weightRange.lowerBound), Self.weightRange.upperBound)
        if clamped == target.defaultWeight {
            weights.removeValue(forKey: target.name)
        } else {
            weights[target.name] = clamped
        }
    }

    /// Clears every authored weight, so the model's own defaults apply.
    func reset() {
        weights.removeAll()
    }

    var hasAuthoredWeights: Bool { !weights.isEmpty }
}

extension EditorWorkbenchViewModel {
    /// One scene-history transaction that sets the weights a Model 3D reference starts with; an empty map removes them.
    @discardableResult
    func setMorphWeights(_ weights: [String: Float], target: EditorSkeletalAnimationTarget) -> Bool {
        guard let document = sceneDocument(id: target.documentID), !document.isReadOnly,
            document.sceneModel?.entities.contains(where: { $0.id == target.entityID }) == true
        else { return false }
        updateSceneModelDocument(id: target.documentID, status: weights.isEmpty ? "Morph weights cleared" : "Morph weights applied") { scene in
            guard let index = scene.entities.firstIndex(where: { $0.id == target.entityID }),
                scene.entities[index].components[EditorBuiltInComponentType.model3DSource] != nil
            else { return }
            if weights.isEmpty {
                scene.entities[index].components[EditorBuiltInComponentType.model3DSource]?.removeValue(forKey: "morphWeights")
            } else {
                scene.entities[index].components[EditorBuiltInComponentType.model3DSource]?["morphWeights"] = EditorMorphWeightsPayload.encode(weights)
            }
        }
        return true
    }
}
