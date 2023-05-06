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
    public var children: OrderedSet<Entity.ID>
    
    public init(parent: Entity.ID? = nil, children: OrderedSet<Entity.ID> = []) {
        self.parent = parent
        self.children = children
    }
}

// MARK: - Relationship

public extension Entity {
    
    /// Contains children if has one.
    var children: [Entity] {
        guard let relationship = self.components[RelationshipComponent.self] else {
            return []
        }
        
        return relationship.children.compactMap {
            self.world?.getEntityByID($0)
        }
    }
    
    /// Contains reference for parent entity if available.
    var parent: Entity? {
        guard let relationship = self.components[RelationshipComponent.self], let parent = relationship.parent else {
            return nil
        }
        
        return self.world?.getEntityByID(parent)
    }
    
    /// Add child entity
    /// - Warning: Will throw assert error if entity contains that child.
    func addChild(_ entity: Entity) {
        assert(!self.children.contains { $0 === entity }, "Currently has entity in child")
        
        guard var relationship = self.components[RelationshipComponent.self] else {
            return
        }
        
        relationship.parent = entity.id
    }
    
    /// Remove entity from children.
    func removeChild(_ entity: Entity) {
        guard var relationship = self.components[RelationshipComponent.self] else {
            return
        }
        
        entity.components[RelationshipComponent.self]?.parent = nil
        relationship.children.remove(entity.id)
    }
    
    /// Remove entity from parent
    func removeFromParent() {
        guard let parent = self.parent else { return }
        parent.removeChild(self)
    }
}
