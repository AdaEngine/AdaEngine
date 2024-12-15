//
//  ModelComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

/// A component that contains a mesh and materials for the visual appearance of an entity.
public struct ModelComponent {

    /// The mesh that defines the model's shape.
    public var mesh: Mesh

    /// The materials that define the model's visual appearance.
    public var materials: [Material]

    public init(mesh: Mesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}
