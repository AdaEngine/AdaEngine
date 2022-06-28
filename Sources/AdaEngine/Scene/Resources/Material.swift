//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public protocol Material: Resource {
    
}

enum MaterialBox: Codable {
    case base(BaseMaterial)
}

public struct BaseMaterial: Material {
    public var diffuseColor: Color
    public var metalic: Float
}
