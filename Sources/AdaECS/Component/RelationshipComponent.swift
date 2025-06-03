//
//  RelationshipComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/20/23.
//

import Collections

/// Contains information about relationship of entity.
@Component
public struct RelationshipComponent {

    /// Identifier of parent entity.
    public var parent: Entity.ID?
    
    /// Contains identifiers of child entities.
    public var children: OrderedSet<Entity.ID>
    
    /// Initialize a new relationship component.
    /// - Parameter parent: The parent entity identifier.
    /// - Parameter children: The children entity identifiers.
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
    
    /// Add child entity.
    /// - Parameter entity: The entity to add as a child.
    /// - Warning: Will throw assert error if entity contains that child.
    func addChild(_ entity: Entity) {
        assert(!self.children.contains { $0 === entity }, "Currently has entity in child")
        assert(self !== entity, "Could not add entity as its child")
        entity.world = self.world
        var relationship = self.components[RelationshipComponent.self] ?? RelationshipComponent()

        entity.components[RelationshipComponent.self]?.parent = self.id
        _ = relationship.children.unordered.insert(entity.id)

        self.components += relationship
    }
    
    /// Remove entity from children.
    /// - Parameter entity: The entity to remove from children.
    func removeChild(_ entity: Entity) {
        guard var relationship = self.components[RelationshipComponent.self] else {
            return
        }

        entity.components[RelationshipComponent.self]?.parent = nil
        relationship.children.remove(entity.id)
        
        self.components += relationship
    }
    
    /// Remove entity from parent
    func removeFromParent() {
        guard let parent = self.parent else { return }
        parent.removeChild(self)
    }
}
