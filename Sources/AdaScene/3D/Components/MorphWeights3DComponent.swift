//
//  MorphWeights3DComponent.swift
//  AdaEngine
//

import AdaECS

/// The weights of an entity's morph targets (blend shapes), one per target of its mesh.
///
/// A weight of 1 applies a target's full displacement and 0 none; values outside that range extrapolate. The renderer applies
/// at most eight targets at once, the ones with the largest weights, and moves vertices before skinning. A model instantiated
/// from glTF gets this component with the weights the file defines.
///
/// Scripts and the inspector cannot read arrays, so they steer one target at a time: pick it with ``selectedTarget`` or
/// ``selectedTargetName`` and set ``selectedTargetWeight``. Code can use ``weights`` and ``setWeight(_:named:)`` directly.
@Component
public struct MorphWeights3DComponent: Codable, Sendable {
    public var weights: [Float]
    /// Names of the targets in weight order, when the asset has them.
    public let targetNames: [String]
    /// The target that ``selectedTargetName`` and ``selectedTargetWeight`` address.
    public var selectedTarget: Int

    public init(weights: [Float], targetNames: [String] = [], selectedTarget: Int = 0) {
        self.weights = weights
        self.targetNames = targetNames
        self.selectedTarget = selectedTarget
    }

    private enum CodingKeys: CodingKey { case weights, targetNames, selectedTarget }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weights = try container.decodeIfPresent([Float].self, forKey: .weights) ?? []
        targetNames = try container.decodeIfPresent([String].self, forKey: .targetNames) ?? []
        selectedTarget = try container.decodeIfPresent(Int.self, forKey: .selectedTarget) ?? 0
    }

    /// The number of targets.
    public var targetCount: Int { weights.count }

    /// The name of the selected target; assigning a name selects that target. Empty when the target has no name.
    public var selectedTargetName: String {
        get { targetNames.indices.contains(selectedTarget) ? targetNames[selectedTarget] : "" }
        set {
            if let index = index(ofTarget: newValue) { selectedTarget = index }
        }
    }

    /// The weight of the selected target (0 when none is selected); assigning a finite value sets it.
    public var selectedTargetWeight: Float {
        get { weights.indices.contains(selectedTarget) ? weights[selectedTarget] : 0 }
        set {
            if weights.indices.contains(selectedTarget), newValue.isFinite { weights[selectedTarget] = newValue }
        }
    }

    /// The index of the target with this name.
    public func index(ofTarget name: String) -> Int? {
        targetNames.firstIndex(of: name)
    }

    /// The current weight of the target with this name.
    public func weight(named name: String) -> Float? {
        guard let index = index(ofTarget: name), weights.indices.contains(index) else { return nil }
        return weights[index]
    }

    /// Sets the weight of the target with this name. Returns `false` when there is no such target.
    @discardableResult
    public mutating func setWeight(_ weight: Float, named name: String) -> Bool {
        guard let index = index(ofTarget: name), weights.indices.contains(index) else { return false }
        weights[index] = weight
        return true
    }
}
