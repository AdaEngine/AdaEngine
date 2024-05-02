//
//  VisibilityComponents.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

/// Contains information about all visible entities on the camera.
@Component
public struct VisibleEntities {
    
    /// Contains visible entities.
    public var entities: [Entity] = []
    
    /// Contains visible entity ids.
    public var entityIds: Set<Entity.ID> = []
}

/// Contains information about visibility of entity.
/// This component indicates that entity can be rendered on the screen.
/// - Note: By default visibility is always true.
@Component
public struct Visibility: Codable {

    public var isVisible: Bool
    
    public init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }
}

/// This components indicates that entity will not affected by frustum culling.
@Component
public struct NoFrustumCulling {
    public init() {}
}
