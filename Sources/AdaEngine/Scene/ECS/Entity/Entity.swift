//
//  Entity.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

// TODO: (Vlad) Make a benchmark
// FIXME: (Vlad) I think we should store components in ComponentTable and avoid storing them in ComponentSet. (Think about after benchmark)
// TODO: (Vlad) Should we create entity with default components?

import Foundation.NSUUID // TODO: (Vlad) Replace to own realization
import OrderedCollections

/// Describe an entity and his characteristics.
/// Entity in ECS based architecture is main object that holds components.
open class Entity: Identifiable {
    
    /// Contains entity name.
    public var name: String
    
    /// Contains unique identifier of entity.
    public private(set) var id: Int
    
    /// Contains components specific for current entity.
    public var components: ComponentSet
    
    /// Contains reference for world where entity placed.
    public internal(set) weak var world: World?
    
    /// Contains children if has one.
    public var children: [Entity] {
        guard let relationship = self.components[RelationshipComponent.self] else {
            return []
        }
        
        return relationship.children.compactMap {
            self.world?.getEntityByID($0)
        }
    }
    
    /// Contains reference for parent entity if available.
    public var parent: Entity? {
        guard let relationship = self.components[RelationshipComponent.self], let parent = relationship.parent else {
            return nil
        }
        
        return self.world?.getEntityByID(parent)
    }
    
    /// Create a new entity.
    /// Also entity contains next components ``Transform``, ``RelationshipComponent`` and ``Visibility``.
    /// - Note: If you want to use entity without any components use ``EmptyEntity``
    /// - Parameter name: Name of entity. By default is `Entity`.
    public init(name: String = "Entity") {
        self.name = name
        self.id = RID().id
        
        var components = ComponentSet()
        components += Transform()
        components += RelationshipComponent()
        components += Visibility()
        
        self.components = components
        
        // swiftlint:disable:next inert_defer
        defer {
            self.components.entity = self
        }
    }
    
    // MARK: - Codable
    
    /// Create entity from decoder.
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.id = try container.decode(Int.self, forKey: .id)
        self.components = try container.decode(ComponentSet.self, forKey: .components)
        self.components.entity = self
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.components, forKey: .components)
    }
    
    // MARK: - Public
    
    /// Remove entity from scene.
    /// - Note: Entity will removed on next update tick.
    public func removeFromScene() {
        self.world?.removeEntityOnNextTick(self)
    }
}

// MARK: - Hashable

extension Entity: Hashable {
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
        hasher.combine(self.id)
    }
}

// MARK: - Relationship

public extension Entity {
    
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

extension Entity: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case components
    }
}
