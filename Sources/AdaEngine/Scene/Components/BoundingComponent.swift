//
//  BoundingComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

/// Contains information about bounds of enitity.
public struct BoundingComponent: Component {
    
    public enum Bounds: Codable {
        case aabb(AABB)
    }
    
    public var bounds: Bounds
    
    public init(bounds: Bounds) {
        self.bounds = bounds
    }
}
