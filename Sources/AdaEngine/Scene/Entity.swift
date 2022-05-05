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
    
    public let identifier: UUID
    
    public internal(set) var components: ComponentSet
    
    public internal(set) weak var scene: Scene?
    
    public internal(set) var children: OrderedSet<Entity>
    
    public internal(set) weak var parent: Entity?
    
    public init(name: String = "Entity") {
        self.name = name
        self.identifier = UUID()
        self.components = ComponentSet()
        self.children = []
        
        defer {
            self.components.entity = self
            self.components[Transform.self] = Transform()
        }
    }
    
    open func update(_ deltaTime: TimeInterval) {
        for component in components.buffer.values {
            if !component.isAwaked {
                component.ready()
                component.isAwaked = true
            }
            
            component.update(deltaTime)
        }
    }
    
    open func physicsUpdate(_ deltaTime: TimeInterval) {
        for component in components.buffer.values where component.isAwaked {
            component.physicsUpdate(deltaTime)
        }
    }
    
    public func removeFromScene() {
        self.scene?.removeEntity(self)
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

public extension Entity {
    
    @frozen
    struct ComponentSet {
        
        internal weak var entity: Entity?
        
        // TODO: looks like not efficient solution
        private(set) var buffer: OrderedDictionary<ObjectIdentifier, Component> = [:]

        /// Gets or sets the component of the specified type.
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                let identifier = ObjectIdentifier(componentType)
                return buffer[identifier] as? T
            }
            
            set {
                let identifier = ObjectIdentifier(componentType)
                self.buffer[identifier] = newValue
                newValue?.entity = entity
            }
        }

        public mutating func set<T>(_ component: T) where T : Component {
            let identifier = ObjectIdentifier(type(of: component))
            self.buffer[identifier] = component
            component.entity = self.entity
        }

        public mutating func set(_ components: [Component]) {
            for component in components {
                let identifier = ObjectIdentifier(type(of: component))
                self.buffer[identifier] = component
                component.entity = self.entity
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.buffer[ObjectIdentifier(componentType)] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            let identifier = ObjectIdentifier(componentType)
            self.buffer[identifier]?.destroy()
            self.buffer[identifier] = nil
        }

        /// Removes all components from the collection.
        public mutating func removeAll() {
            self.buffer.forEach { $0.value.destroy() }
            
            self.buffer.removeAll()
        }

        /// The number of components in this collection.
        public var count: Int {
            return self.buffer.count
        }
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
