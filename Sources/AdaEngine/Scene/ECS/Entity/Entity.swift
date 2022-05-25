//
//  Entity.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Foundation.NSUUID // TODO: Replace to own realization
import OrderedCollections

/// An enity describe
open class Entity {
    
    public var name: String
    
    // TODO: Replace to UInt32 to avoid big capacity on id
    public private(set) var identifier: UUID
    
    public var components: ComponentSet
    
    public internal(set) weak var scene: Scene? {
        didSet {
            self.children.forEach {
                $0.scene = scene
            }
        }
    }
    
    public internal(set) var children: OrderedSet<Entity>
    
    // TODO: Looks like parentnes not a good choice to ECS data oriented way
    public internal(set) weak var parent: Entity?
    
    public init(name: String = "Entity") {
        self.name = name
        self.identifier = UUID()
        self.components = ComponentSet()
        self.children = []
        
        // swiftlint:disable:next inert_defer
        defer {
            self.components.entity = self
            self.components[Transform.self] = Transform()
        }
    }
    
    // MARK: - Codable
    
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.identifier = try container.decode(UUID.self, forKey: .id)
        self.children = try container.decodeIfPresent(OrderedSet<Entity>.self, forKey: .children) ?? []
        let components = try container.decodeIfPresent(ComponentSet.self, forKey: .components)
        
        if let components = components {
            self.components.set(components.buffer.values.elements)
        }
        
        self.children.forEach { $0.parent = self }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.identifier, forKey: .id)
        
        if !self.children.isEmpty {
            try container.encode(self.children, forKey: .children)
        }
        
        if !self.components.isEmpty {
            try container.encode(self.components, forKey: .components)
        }
    }
    
    // MARK: - Public
    
    public func removeFromScene() {
        self.scene?.removeEntity(self)
    }
    
    // TODO: think about more cache frendly
    func performQuery(_ query: EntityQuery) -> [Entity] {
        var entities = [Entity]()
        
        if query.predicate.fetch(self) {
            entities.append(self)
        }
        
        for child in children {
            let array = child.performQuery(query)
            if !array.isEmpty {
                entities.append(contentsOf: array)
            }
        }
        
        return entities
    }
    
}

extension Entity: Hashable {
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs === rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
        hasher.combine(self.identifier)
    }
}

extension Entity: Identifiable {
    public var id: UUID {
        return self.identifier
    }
}

extension Entity {
    
    /// Copying entity with components
    /// - Parameter recursive: Flags indicate that child enities will copying too
    open func copy(recursive: Bool = true) -> Entity {
        let newEntity = Entity()
        
        if recursive {
            var childrens = self.children
            
            for index in 0..<childrens.count {
                let child = self.children[index].copy(recursive: true)
                childrens.updateOrAppend(child)
            }
            
            newEntity.children = childrens
        }
        
        newEntity.components = self.components
        newEntity.scene = self.scene
        newEntity.parent = self.parent
        
        return newEntity
    }
    
    open func addChild(_ entity: Entity) {
        assert(!self.children.contains { $0 === entity }, "Currenlty has entity in child")
        
        self.children.append(entity)
        entity.parent = self
    }
    
    open func removeChild(_ entity: Entity) {
        guard let index = self.children.firstIndex(where: { $0 === entity }) else {
            return
        }
        
        entity.parent = nil
        
        self.children.remove(at: index)
    }
    
    /// Remove entity from parent
    open func removeFromParent() {
        guard let parent = self.parent else { return }
        parent.removeChild(self)
    }
}

extension Entity: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case components
        case children
    }
}
