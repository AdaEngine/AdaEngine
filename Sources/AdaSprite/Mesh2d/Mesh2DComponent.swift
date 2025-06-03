//
//  Mesh2DComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

import AdaECS
import AdaRender

/// Component that hold mesh and collection of materials for rendering.
@Component
public struct Mesh2DComponent: Sendable {
    public var mesh: Mesh
    public var materials: [Material]
    
    public init(mesh: Mesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}
