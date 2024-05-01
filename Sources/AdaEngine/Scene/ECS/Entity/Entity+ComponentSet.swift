//
//  Entity+ComponentSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/22.
//

import Collections

public extension Entity {
    
    /// Hold entity components specific for entity.
    struct ComponentSet: Codable, Sendable {
        
        internal weak var entity: Entity?
        
        let lock = NSLock()
        
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
            
            for key in container.allKeys {
                guard let type = ComponentStorage.getRegisteredComponent(for: key.stringValue) else {
                    continue
                }

//                let component = try type.init(from: container.superDecoder(forKey: key))
//                self.set(component)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            
            for value in self.buffer.values {
//                let superEncoder = container.superEncoder(forKey: CodingName(stringValue: type(of: value).swiftName))
//                try value.encode(to: superEncoder)
            }
        }

        /// Gets or sets the component of the specified type.
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                lock.lock()
                defer { lock.unlock() }
                
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
            lock.lock()
            defer { lock.unlock() }
            
            let identifier = T.identifier
            self.buffer[identifier] = component
            (component as? ScriptComponent)?.entity = self.entity
            self.bitset.insert(T.self)
            if let ent = self.entity {
                self.world?.entity(ent, didAddComponent: component, with: identifier)
            }
        }

        /// Set the components of the specified type.
        public mutating func set(_ components: [Component]) {
            lock.lock()
            defer { lock.unlock() }
            
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
            lock.lock()
            defer { lock.unlock() }
            return self.buffer[componentType.identifier] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            lock.lock()
            defer { lock.unlock() }
            
            let identifier = componentType.identifier
            (self.buffer[identifier] as? ScriptComponent)?.onDestroy()
            self.buffer[identifier] = nil
            
            self.bitset.remove(componentType)
            
            if let ent = self.entity {
                self.world?.entity(ent, didRemoveComponent: componentType, with: identifier)
            }
        }
        
        /// Remove all components from set.
        public mutating func removeAll(keepingCapacity: Bool = false) {
            lock.lock()
            defer { lock.unlock() }
            
            for component in self.buffer.values.elements {
                let componentType = type(of: component)
                (component as? ScriptComponent)?.onDestroy()

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
    }
}

// swiftlint:disable identifier_name

public extension Entity.ComponentSet {
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B>(_ a: A.Type, _ b: B.Type) -> (A, B) where A : Component, B: Component {
        lock.lock()
        defer { lock.unlock() }
        
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B
        )
    }
    
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B, C>(_ a: A.Type, _ b: B.Type, _ c: C.Type) -> (A, B, C) where A : Component, B: Component, C: Component {
        lock.lock()
        defer { lock.unlock() }
        
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C
        )
    }
    
    /// Gets the components of the specified types.
    @inline(__always)
    subscript<A, B, C, D>(_ a: A.Type, _ b: B.Type, _ c: C.Type, _ d: D.Type) -> (A, B, C, D) where A : Component, B: Component, C: Component, D: Component {
        lock.lock()
        defer { lock.unlock() }
        
        return (
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
