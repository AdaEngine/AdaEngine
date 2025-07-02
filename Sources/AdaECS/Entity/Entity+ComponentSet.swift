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
        public var entity: Entity.ID

        weak var world: World?
        
        // MARK: - Codable
        
        /// Create an empty component set.
        init(entity: Entity.ID) {
            self.entity = entity
        }

        /// Create a component set from another component set.
        /// - Parameter other: The other component set to create a component set from.
        init(from other: borrowing Self) {
            self.entity = other.entity
        }
        
        /// Create component set from decoder.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            self.entity = RID().id

            for key in container.allKeys {
                guard let type = ComponentStorage.getRegisteredComponent(for: key.stringValue)
                else {
                    continue
                }

                if let decodable = type as? Decodable.Type {
                    let component = try decodable.init(from: container.superDecoder(forKey: key))
//                    self.buffer[type.identifier] = component as? Component
//                    self.bitset.insert(type.identifier)
                }
            }
        }
        
        /// Encode the component set to an encoder.
        /// - Parameter encoder: The encoder to encode the component set to.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
//            for component in self.buffer.elements.values {
//                do {
//                    try container.encode(AnyEncodable(component), forKey: CodingName(stringValue: type(of: component).swiftName))
//                } catch {
//                    print("Component encoding error: \(error)")
//                }
//            }
        }

        /// Gets or sets the component of the specified type.
        @inline(__always)
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                return world?.get(from: entity)
            }
            
            set {
                if let newValue {
                    self.set(newValue)
                } else {
                    self.remove(T.self)
                }
            }
        }

        // FIXME: Replace to subscript??
        /// Get any count of component types from set.
        @inline(__always)
        public func get<each T: Component>(_ type: repeat (each T).Type) -> (repeat each T) {
            return (repeat self.world!.get((each T).self, from: entity)!)
        }

        /// Set the component of the specified type.
        @inline(__always)
        public mutating func set<T>(_ component: consuming T) where T : Component {            
            self.world?.set(component, for: entity)
        }

        /// Set the components of the specified type.
        @inline(__always)
        public mutating func set<each T: Component>(_ components: consuming (repeat (each T))) {
            for component in repeat (each components) {
                self.set(component)
            }
        }

        /// Set the components of the specified type using ``ComponentsBuilder``.
        public mutating func set(@ComponentsBuilder components: () -> [Component]) {
            let components = components()
            for component in components {
                self.set(component)
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.world?.has(componentType.identifier, in: entity) ?? false
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentId: ComponentId) -> Bool {
            return self.world?.has(componentId, in: entity) ?? false
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            self.world?.remove(componentType.identifier, from: entity)
        }
        
        /// The number of components in the set.
        public var count: Int {
            guard
                let world,
                let location = world.entities.entities[entity]
            else {
                return 0
            }
            return world.archetypes
                .archetypes[location.archetypeId]
                .chunks.chunks.getPointer(at: location.chunkIndex)
                .pointee
                .getComponents(for: entity)
                .count
        }
        
        /// A Boolean value indicating whether the set is empty.
        public var isEmpty: Bool {
            return count == 0
        }
  
        /// Check if a component is changed.
        /// - Parameter componentType: The type of the component to check.
        /// - Returns: True if the component is changed, otherwise false.
        public func isComponentChanged<T: Component>(_ componentType: T.Type) -> Bool {
            return world?.isComponentChanged(componentType, for: entity) ?? false
        }

        /// Copy the component set.
        /// - Returns: A new component set with the same components.
        public func copy() -> Self {
            return Self(from: self)
        }
    }
}

// swiftlint:disable identifier_name

public extension Entity.ComponentSet {
    /// Gets the components of the specified types.
    /// - Parameter a: The type of the first component.
    /// - Parameter b: The type of the second component.
    /// - Returns: The components of the specified types.
    @inline(__always)
    subscript<A, B>(_ a: A.Type, _ b: B.Type) -> (A, B) where A : Component, B: Component {
        (
            world!.get(A.self, from: entity)!,
            world!.get(B.self, from: entity)!
        )
    }
    
    /// Gets the components of the specified types.
    /// - Parameter a: The type of the first component.
    /// - Parameter b: The type of the second component.
    /// - Parameter c: The type of the third component.
    /// - Returns: The components of the specified types.
    @inline(__always)
    subscript<A, B, C>(
        _ a: A.Type,
        _ b: B.Type,
        _ c: C.Type
    ) -> (A, B, C) where A : Component, B: Component, C: Component {
        (
            world!.get(A.self, from: entity)!,
            world!.get(B.self, from: entity)!,
            world!.get(C.self, from: entity)!
        )
    }
    
    /// Gets the components of the specified types.
    /// - Parameter a: The type of the first component.
    /// - Parameter b: The type of the second component.
    /// - Parameter c: The type of the third component.
    /// - Parameter d: The type of the fourth component.
    /// - Returns: The components of the specified types.
    @inline(__always)
    subscript<A, B, C, D>(
        _ a: A.Type,
        _ b: B.Type,
        _ c: C.Type,
        _ d: D.Type
    ) -> (A, B, C, D) where A : Component, B: Component, C: Component, D: Component {
        (
            world!.get(A.self, from: entity)!,
            world!.get(B.self, from: entity)!,
            world!.get(C.self, from: entity)!,
            world!.get(D.self, from: entity)!
        )
    }
}

public extension Entity.ComponentSet {
    /// Add new component to component set.
    @inline(__always)
    static func += <T: Component>(lhs: inout Self, rhs: consuming T) {
        lhs[T.self] = rhs
    }
}

extension Entity.ComponentSet: CustomStringConvertible {
    public var description: String {
        guard
            let world,
            let location = world.entities.entities[entity]
        else {
            return "ComponentSet(entity: \(entity), world: nil)"
        }
        let chunk = world.archetypes
            .archetypes[location.archetypeId]
            .chunks.chunks.getPointer(at: location.chunkIndex)
        let components = chunk.pointee.getComponents(for: entity)
        let result = components.reduce("") { partialResult, value in
            let name = type(of: value.value)
            return partialResult + "\n   ⟐ \(name)"
        }
        
        return "ComponentSet(\(result)\n)"
    }
}

extension Entity.ComponentSet {
    /// Get a component by its identifier.
    /// - Parameter identifier: The identifier of the component.
    /// - Returns: The component if it exists, otherwise nil.
    func get<T: Component>(by identifier: ComponentId) -> T? {
        return self.world?.get(T.self, from: entity)
    }
    
    /// Get a component by its identifier.
    /// - Parameter componentId: The identifier of the component.
    /// - Returns: The component if it exists, otherwise nil.
    subscript<T: Component>(by componentId: ComponentId) -> T? {
        get {
            return world?.get(T.self, from: entity)
        }
        
        set {
            if let newValue {
                world?.set(newValue, for: entity)
            } else {
                world?.remove(T.identifier, from: entity)
            }
        }
    }
}

// swiftlint:enable identifier_name
