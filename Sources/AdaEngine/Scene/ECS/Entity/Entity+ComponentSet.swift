//
//  Entity+ComponentSet.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Collections

public extension Entity {
    
    /// Hold entity components
    @frozen struct ComponentSet: Codable {
        
        internal weak var entity: Entity?
        
        // TODO: looks like not efficient solution
        private(set) var buffer: Dictionary<ObjectIdentifier, Component>
        
        // MARK: - Codable
        
        init() {
            self.buffer = [:]
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            
            var buffer: Dictionary<ObjectIdentifier, Component> = [:]
            
            for key in container.allKeys {
                guard let type = ComponentStorage.getRegistredComponent(for: key.stringValue) else {
                    continue
                }
                
                let component = try type.init(from: container.superDecoder(forKey: key))
                
                buffer[ObjectIdentifier(type)] = component
            }
            
            self.buffer = buffer
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            
            for (_, value) in self.buffer {
                let superEncoder = container.superEncoder(forKey: CodingName(stringValue: type(of: value).swiftName))
                try value.encode(to: superEncoder)
            }
        }

        /// Gets or sets the component of the specified type.
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                return buffer[ObjectIdentifier(componentType)] as? T
            }
            
            set {
                self.buffer[ObjectIdentifier(componentType)] = newValue
                
                (newValue as? ScriptComponent)?.entity = entity
            }
        }

        public mutating func set<T>(_ component: T) where T : Component {
            self.buffer[ObjectIdentifier(T.self)] = component
            (component as? ScriptComponent)?.entity = self.entity
        }

        public mutating func set(_ components: [Component]) {
            for component in components {
                self.buffer[ObjectIdentifier(type(of: component))] = component
                (component as? ScriptComponent)?.entity = self.entity
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.buffer[ObjectIdentifier(componentType)] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            let identifier = ObjectIdentifier(componentType)
            (self.buffer[identifier] as? ScriptComponent)?.destroy()
            self.buffer[identifier] = nil
        }

        /// Removes all components from the collection.
        public mutating func removeAll() {
            self.buffer.forEach { ($0.value as? ScriptComponent)?.destroy() }
            
            self.buffer.removeAll()
        }

        /// The number of components in the set.
        public var count: Int {
            return self.buffer.count
        }
        
        /// A Boolean value indicating whether the set is empty.
        public var isEmpty: Bool {
            return self.buffer.isEmpty
        }
    }
}

// swiftlint:disable identifier_name

public extension Entity.ComponentSet {
    /// Gets the components of the specified types.
    subscript<A, B>(_ a: A.Type, _ b: B.Type) -> (A, B) where A : Component, B: Component {
        return (
            buffer[ObjectIdentifier(a)] as! A,
            buffer[ObjectIdentifier(b)] as! B
        )
    }
    
    /// Gets the components of the specified types.
    subscript<A, B, C>(_ a: A.Type, _ b: B.Type, _ c: C.Type) -> (A, B, C) where A : Component, B: Component, C: Component {
        return (
            buffer[ObjectIdentifier(a)] as! A,
            buffer[ObjectIdentifier(b)] as! B,
            buffer[ObjectIdentifier(c)] as! C
        )
    }
    
    /// Gets the components of the specified types.
    subscript<A, B, C, D>(_ a: A.Type, _ b: B.Type, _ c: C.Type, _ d: D.Type) -> (A, B, C, D) where A : Component, B: Component, C: Component, D: Component {
        return (
            buffer[ObjectIdentifier(a)] as! A,
            buffer[ObjectIdentifier(b)] as! B,
            buffer[ObjectIdentifier(c)] as! C,
            buffer[ObjectIdentifier(d)] as! D
        )
    }
}

public extension Entity.ComponentSet {
    static func += <T: Component>(lhs: inout Self, rhs: T) {
        lhs[T.self] = rhs
    }
}

// swiftlint:enable identifier_name
