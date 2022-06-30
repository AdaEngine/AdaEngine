//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public protocol Material: Resource {
    
}

public struct BaseMaterial {
    public var diffuseColor: Color
    public var metalic: Float
}
