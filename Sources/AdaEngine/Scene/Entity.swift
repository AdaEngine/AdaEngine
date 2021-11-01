//
//  Entity.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Foundation

public typealias TimeInterval = Float

open class Component {
    
    internal var isAwaked: Bool = false
    
    weak var entity: Entity?
    
    open func awake() {
        
    }
    
    open func update(_ deltaTime: TimeInterval) {
        
    }
    
    open func shutdown() {
        
    }
}

extension Component {
    var components: Entity.ComponentSet {
        return self.entity!.components
    }
    
    func setComponent<T: Component>(_ component: T) {
        self.entity?.components.set(component)
    }
}

open class Entity {
    
    public weak var scene: Scene?
    
    public var name: String
    
    internal var components: ComponentSet
    
    public init() {
        self.name = "Entity \(UUID().uuid)"
        self.components = ComponentSet()
        
        defer {
            self.components.entity = self
            self.components[Transform] = Transform()
        }
    }
    
    func update(_ deltaTime: TimeInterval) {
        for component in components.buffer.values {
            
            if !component.isAwaked {
                component.awake()
                component.isAwaked = true
            }
            
            component.update(deltaTime)
        }
    }
    
}

extension Entity: Hashable {
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs === rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
    }
}


public extension Entity {
    
    @frozen
    struct ComponentSet {
        
        weak var entity: Entity?
        
        // TODO: looks like not efficient solution
        private(set) var buffer: [ObjectIdentifier: Component] = [:]

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

        /// Gets or sets the component of the specified type.
        public subscript(componentType: Component.Type) -> Component? {
            let identifier = ObjectIdentifier(componentType)
            return buffer[identifier]
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
            self.buffer[identifier]?.shutdown()
            self.buffer[identifier] = nil
        }

        /// Removes all components from the collection.
        public mutating func removeAll() {
            self.buffer.forEach { $0.value.shutdown() }
            
            self.buffer.removeAll()
        }

        /// The number of components in this collection.
        public var count: Int {
            return self.buffer.count
        }
    }
}
