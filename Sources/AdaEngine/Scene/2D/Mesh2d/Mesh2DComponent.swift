//
//  Mesh2DComponent.swift
//  
//
//  Created by v.prusakov on 4/2/23.
//

public struct Mesh2DComponent: Component {
    public var mesh: Mesh
    public var materials: [Material]
    
    public init(mesh: Mesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}
