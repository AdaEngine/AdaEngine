//
//  VisibilityComponents.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

/// Contains information about all visible entities on the camera.
public struct VisibleEntities: Component {
    public var entities: [Entity] = []
    public var entityIds: Set<Entity.ID> = []
}

/// Contains information about visibility of entity.
/// This component indicates that object can be rendered on the screen.
/// - Note: By default visibility is always true
public struct Visibility: Component {
    
    public var isVisible: Bool
    
    public init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }
}

/// This components indicates that entity will not affected by frustum culling.
public struct NoFrustumCulling: Component {
    public init() {}
}
