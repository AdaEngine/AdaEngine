//
//  Entity+ComponentSet.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Collections

public extension Entity {
    
    /// Hold entity components
    struct ComponentSet: Codable {
        
        internal weak var entity: Entity?
        
        var world: World? {
            return self.entity?.scene?.world
        }
        
        private(set) var buffer: OrderedDictionary<ComponentId, Component>
        private(set) var bitset: Bitset
        
        // MARK: - Codable
        
        init() {
            self.bitset = Bitset()
            self.buffer = [:]
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            self.buffer = OrderedDictionary<ComponentId, Component>.init(minimumCapacity: container.allKeys.count)
            self.bitset = Bitset(count: container.allKeys.count)
            
            for key in container.allKeys {
                guard let type = ComponentStorage.getRegisteredComponent(for: key.stringValue) else {
                    continue
                }

                let component = try type.init(from: container.superDecoder(forKey: key))
                self.set(component)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            
            for value in self.buffer.values {
                let superEncoder = container.superEncoder(forKey: CodingName(stringValue: type(of: value).swiftName))
                try value.encode(to: superEncoder)
            }
        }

        /// Gets or sets the component of the specified type.
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                return buffer[T.identifier] as? T
            }
            
            set {
                if let newValue {
                    self.set(newValue)
                } else {
                    self.remove(T.self)
                }
            }
        }

        public mutating func set<T>(_ component: T) where T : Component {
            let identifier = T.identifier
            self.buffer[identifier] = component
            (component as? ScriptComponent)?.entity = self.entity
            self.bitset.insert(T.self)
            if let ent = self.entity {
                self.world?.entity(ent, didAddComponent: component, with: identifier)
            }
        }

        public mutating func set(_ components: [Component]) {
            for component in components {
                
                let componentType = type(of: component)
                
                let identifier = componentType.identifier
                self.buffer[identifier] = component
                (component as? ScriptComponent)?.entity = self.entity
                self.bitset.insert(identifier)
                
                if let ent = self.entity {
                    self.world?.entity(ent, didAddComponent: component , with: identifier)
                }
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.buffer[componentType.identifier] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            let identifier = componentType.identifier
            (self.buffer[identifier] as? ScriptComponent)?.destroy()
            self.buffer[identifier] = nil
            
            self.bitset.remove(componentType)
            
            if let ent = self.entity {
                self.world?.entity(ent, didRemoveComponent: componentType, with: identifier)
            }
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
    @inline(__always)
    subscript<A, B>(_ a: A.Type, _ b: B.Type) -> (A, B) where A : Component, B: Component {
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B
        )
    }
    
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B, C>(_ a: A.Type, _ b: B.Type, _ c: C.Type) -> (A, B, C) where A : Component, B: Component, C: Component {
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C
        )
    }
    
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B, C, D>(_ a: A.Type, _ b: B.Type, _ c: C.Type, _ d: D.Type) -> (A, B, C, D) where A : Component, B: Component, C: Component, D: Component {
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C,
            buffer[d.identifier] as! D
        )
    }
}

public extension Entity.ComponentSet {
    @inline(__always)
    static func += <T: Component>(lhs: inout Self, rhs: T) {
        lhs[T.self] = rhs
    }
}

extension Entity.ComponentSet: CustomStringConvertible {
    public var description: String {
        let result = self.buffer.reduce("") { partialResult, value in
            let name = type(of: value.value)
            return partialResult + "\n   ⟐ \(name)"
        }
        
        return "ComponentSet(entity: \(self.entity?.name ?? "\'\'"),\(result)\n)"
    }
}

// swiftlint:enable identifier_name
