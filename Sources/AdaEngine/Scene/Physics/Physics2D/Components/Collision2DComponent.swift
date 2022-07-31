//
//  Collision2DComponent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

public struct Collision2DComponent: Component {
    
    internal var runtimeBody: Body2D?
    public var shapes: [Shape2DResource] = []
    public var mode: Mode
    public var filter: CollisionFilter
    
    public init(
        shapes: [Shape2DResource],
        mode: Mode = .default,
        filter: CollisionFilter = CollisionFilter()
    ) {
        self.mode = mode
        self.shapes = shapes
        self.filter = filter
    }
}

public extension Collision2DComponent {
    enum Mode {
        case trigger
        case `default`
    }
}
