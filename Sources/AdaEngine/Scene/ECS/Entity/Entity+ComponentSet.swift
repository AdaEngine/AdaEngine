//
//  Entity+ComponentSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/22.
//

import Collections

public extension Entity {
    
    /// Hold entity components specific for entity.
    @MainActor
    struct ComponentSet: Codable, @unchecked Sendable {

        internal weak var entity: Entity?
        
        var world: World? {
            return self.entity?.world
        }
        
        private(set) var buffer: OrderedDictionary<ComponentId, Component>
        private(set) var bitset: BitSet
        
        // MARK: - Codable
        
        /// Create an empty component set.
        init() {
            self.bitset = BitSet()
            self.buffer = [:]
        }
        
        /// Create component set from decoder.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            self.buffer = OrderedDictionary<ComponentId, Component>.init(minimumCapacity: container.allKeys.count)
            self.bitset = BitSet(reservingCapacity: container.allKeys.count)
            
            // for key in container.allKeys {
            //     guard let type = ComponentStorage.getRegisteredComponent(for: key.stringValue) else {
            //         continue
            //     }

//                let component = try type.init(from: container.superDecoder(forKey: key))
//                self.set(component)
            // }
        }
        
        public func encode(to encoder: Encoder) throws {
            // var container = encoder.container(keyedBy: CodingName.self)
            
            // for value in self.buffer.values {
//                let superEncoder = container.superEncoder(forKey: CodingName(stringValue: type(of: value).swiftName))
//                try value.encode(to: superEncoder)
            // }
        }

        // FIXME: Replace to subscript??

        /// Get any count of component types from set.
        @inline(__always)
        public func get<each T: Component>(_ type: repeat (each T).Type) -> (repeat each T) {
            return (repeat self.buffer[(each type).identifier] as! each T)
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

        /// Set the component of the specified type.
        public mutating func set<T>(_ component: T) where T : Component {
            var isChanged = false
            let identifier = T.identifier
            if self.buffer[identifier] != nil {
                isChanged = true
            }

            self.buffer[identifier] = component
            (component as? ScriptableComponent)?.entity = self.entity
            self.bitset.insert(T.self)
            guard let ent = self.entity else {
                return
            }

            if isChanged {
                self.world?.entity(ent, didUpdateComponent: component, with: identifier)
            } else {
                self.world?.entity(ent, didAddComponent: component, with: identifier)
            }
        }

        /// Set the components of the specified type.
        public mutating func set(_ components: [Component]) {
            for component in components {
                
                let componentType = type(of: component)
                
                let identifier = componentType.identifier

                var isChanged = false
                if self.buffer[identifier] != nil {
                    isChanged = true
                }

                self.buffer[identifier] = component
                (component as? ScriptableComponent)?.entity = self.entity
                self.bitset.insert(identifier)
                
                guard let ent = self.entity else {
                    continue
                }

                if isChanged {
                    self.world?.entity(ent, didUpdateComponent: component, with: identifier)
                } else {
                    self.world?.entity(ent, didAddComponent: component, with: identifier)
                }
            }
        }

        /// Set the components of the specified type using ``ComponentsBuilder``.
        public mutating func set(@ComponentsBuilder components: () -> [Component]) {
            self.set(components())
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.buffer[componentType.identifier] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            let identifier = componentType.identifier
            (self.buffer[identifier] as? ScriptableComponent)?.onDestroy()
            self.buffer[identifier] = nil
            
            self.bitset.remove(componentType)
            
            if let ent = self.entity {
                self.world?.entity(ent, didRemoveComponent: componentType, with: identifier)
            }
        }
        
        /// Remove all components from set.
        public mutating func removeAll(keepingCapacity: Bool = false) {
            for component in self.buffer.values.elements {
                let componentType = type(of: component)
                (component as? ScriptableComponent)?.onDestroy()

                if let ent = self.entity {
                    self.world?.entity(ent, didRemoveComponent: componentType, with: componentType.identifier)
                }
            }
            
            self.bitset = BitSet(reservingCapacity: self.buffer.count)
            
            self.buffer.removeAll(keepingCapacity: keepingCapacity)
        }
        
        /// The number of components in the set.
        public var count: Int {
            return self.buffer.count
        }
        
        /// A Boolean value indicating whether the set is empty.
        public var isEmpty: Bool {
            return self.buffer.isEmpty
        }
        
        public func isComponentChanged<T: Component>(_ componentType: T.Type) -> Bool {
            guard let entity = self.entity else {
                return false
            }

            return world?.isComponentChanged(T.identifier, for: entity) ?? false
        }
        
        public func isComponentChanged<T: Component>(_ component: T) -> Bool {
            return self.isComponentChanged(T.self)
        }
    }
}

// swiftlint:disable identifier_name

public extension Entity.ComponentSet {
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B>(_ a: A.Type, _ b: B.Type) -> (A, B) where A : Component, B: Component {
        (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B
        )
    }
    
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B, C>(_ a: A.Type, _ b: B.Type, _ c: C.Type) -> (A, B, C) where A : Component, B: Component, C: Component {
        (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C
        )
    }
    
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B, C, D>(_ a: A.Type, _ b: B.Type, _ c: C.Type, _ d: D.Type) -> (A, B, C, D) where A : Component, B: Component, C: Component, D: Component {
        (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C,
            buffer[d.identifier] as! D
        )
    }
}

public extension Entity.ComponentSet {
    /// Add new component to component set.
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
        
        return "ComponentSet(\(result)\n)"
    }
}

// swiftlint:enable identifier_name
