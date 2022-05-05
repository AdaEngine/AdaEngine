//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public protocol Material: Resource {
    var renderPriority: Int { get set }
}

public struct BaseMaterial: Material {
    public var renderPriority: Int = 0
    public var diffuseColor: Color
    public var metalic: Float
}
