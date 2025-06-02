//
//  Entity+ComponentSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation
import AdaUtils
import Collections

public extension Entity {
    
    /// Hold entity components specific for entity.
    struct ComponentSet: Codable, Sendable {
        @_spi(Internal)
        public weak var entity: Entity?
        
        var world: World? {
            return self.entity?.world
        }
        
        let lock = NSRecursiveLock()

        @_spi(Internal)
        @LocalIsolated public private(set) var buffer: OrderedDictionary<ComponentId, Component>
        private(set) var bitset: BitSet
        
        // MARK: - Codable
        
        /// Create an empty component set.
        init() {
            self.bitset = BitSet()
            self.buffer = [:]
        }

        init(from other: borrowing Self) {
            self.buffer = other.buffer
            self.bitset = other.bitset
        }
        
        /// Create component set from decoder.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            self.buffer = OrderedDictionary<ComponentId, Component>(
                minimumCapacity: container.allKeys.count
            )
            self.bitset = BitSet(reservingCapacity: container.allKeys.count)

            for key in container.allKeys {
                guard let type = ComponentStorage.getRegisteredComponent(for: key.stringValue)
                else {
                    continue
                }

                if let decodable = type as? Decodable.Type {
                    let component = try decodable.init(from: container.superDecoder(forKey: key))
                    self.buffer[type.identifier] = component as? Component
                    self.bitset.insert(type.identifier)
                }
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            for component in self.buffer.elements.values {
                do {
                    try container.encode(AnyEncodable(component), forKey: CodingName(stringValue: type(of: component).swiftName))
                } catch {
                    print("Component encoding error: \(error)")
                }
            }
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
            lock.lock()
            defer {
                lock.unlock()
            }
            
            let identifier = T.identifier
            let isChanged = self.buffer[identifier] != nil
            
            self.buffer[identifier] = component
            self.bitset.insert(T.identifier)
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
                let isChanged = self.buffer[identifier] != nil
                self.buffer[identifier] = component
                self.bitset.insert(identifier)
                
                guard let ent = self.entity else {
                    continue
                }

                lock.lock()
                defer {
                    lock.unlock()
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
            self.buffer[identifier] = nil
            
            self.bitset.remove(componentType)
            
            guard let ent = self.entity else { return }
            world?.entity(ent, didRemoveComponent: componentType, with: identifier)
        }
        
        /// Remove all components from set.
        public mutating func removeAll(keepingCapacity: Bool = false) {
            for component in self.buffer.values.elements {
                let componentType = type(of: component)

                guard let ent = self.entity else { return }
                world?.entity(ent, didRemoveComponent: componentType, with: componentType.identifier)
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

            return world?.isComponentChanged(componentType, for: entity) ?? false
        }

        public func copy() -> Self {
            return Self(from: self)
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

private extension Entity.ComponentSet {
    struct ComponentRepresentable<T: Codable>: Codable {
        let type: String
        let value: T
    }
}

extension Entity.ComponentSet {
    func get<T: Component>(by identifier: ComponentId) -> T? {
        return (self.buffer[identifier] as? T)
    }
    
    subscript<T: Component>(by componentId: ComponentId) -> T? where T : Component {
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
}

// swiftlint:enable identifier_name
