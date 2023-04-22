//
//  RelationshipComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/20/23.
//

import Collections

/// Contains information about relationship of entity.
public struct RelationshipComponent: Component {
    
    /// Identifier of parent entity.
    public var parent: Entity.ID?
    
    /// Contains identifiers of child entities.
    public var children: OrderedSet<Entity.ID> = []
}
