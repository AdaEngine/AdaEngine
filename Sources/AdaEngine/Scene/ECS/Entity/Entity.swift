//
//  Entity.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Foundation.NSUUID // TODO: (Vlad) Replace to own realization
import OrderedCollections

// - TODO: (Vlad) Should fix
// - [ ] Entity children
/// Describe an entity and his characteristics.
open class Entity: Identifiable {
    
    public var name: String
    
    public private(set) var id: Int
    
    public var components: ComponentSet
    
    public internal(set) weak var scene: Scene?
    
    public var children: [Entity] {
        guard let relationship = self.components[RelationshipComponent.self] else {
            return []
        }
        
        return relationship.children.compactMap {
            self.scene?.world.getEntityByID($0)
        }
    }
    
    public var parent: Entity? {
        guard let relationship = self.components[RelationshipComponent.self], let parent = relationship.parent else {
            return nil
        }
        
        return self.scene?.world.getEntityByID(parent)
    }
    
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
    
    public func removeFromScene() {
        self.scene?.removeEntity(self)
    }
    
}

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
    
    func addChild(_ entity: Entity) {
        assert(!self.children.contains { $0 === entity }, "Currently has entity in child")
        
        guard var relationship = self.components[RelationshipComponent.self] else {
            return
        }
        
        relationship.parent = entity.id
    }
    
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
