//
//  BoundingComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

/// Contains information about bounds of entity.
@Component
public struct BoundingComponent {
    
    public enum Bounds: Codable, Sendable {
        case aabb(AABB)
    }
    
    public var bounds: Bounds
    
    public init(bounds: Bounds) {
        self.bounds = bounds
    }
}
