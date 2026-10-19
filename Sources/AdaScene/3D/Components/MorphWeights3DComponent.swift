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
public struct MorphWeights3DComponent: Component {
    public var weights: [Float]
    /// Names of the targets in weight order, when the asset has them.
    public let targetNames: [String]

    public init(weights: [Float], targetNames: [String] = []) {
        self.weights = weights
        self.targetNames = targetNames
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
