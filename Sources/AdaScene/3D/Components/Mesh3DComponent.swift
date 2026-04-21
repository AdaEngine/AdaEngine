//
//  Mesh3DComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaECS
import AdaRender
import AdaAssets

/// A component that renders a 3D mesh.
public struct Mesh3DComponent: Component {
    public var mesh: Mesh
    public var materials: [Material]
    
    public init(mesh: Mesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}
