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
/// An enity describe
open class Entity: Identifiable {
    
    public var name: String
    
    public private(set) var id: Int
    
    public var components: ComponentSet
    
    public internal(set) weak var scene: Scene? {
        didSet {
            self.children.forEach {
                $0.scene = scene
            }
        }
    }
    
    // TODO: (Vlad) We should reimagine how it works, fit it to ECS World
    public internal(set) var children: OrderedSet<Entity>
    
    // TODO: (Vlad) Looks like parentnes not a good choice to ECS data oriented way
    public internal(set) weak var parent: Entity?
    
    public init(name: String = "Entity") {
        self.name = name
        self.id = RID().id
        
        var components = ComponentSet()
        components += Transform()
        
        self.components = components
        self.children = []
        
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
        self.children = try container.decodeIfPresent(OrderedSet<Entity>.self, forKey: .children) ?? []
        let components = try container.decodeIfPresent(ComponentSet.self, forKey: .components)
//        
//        if let components = components {
//            self.components.set(components.buffer.values.elements)
//        }
        
        self.children.forEach { $0.parent = self }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.id, forKey: .id)
        
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
