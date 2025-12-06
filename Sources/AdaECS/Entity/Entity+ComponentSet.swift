//
//  Entity+ComponentSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/22.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AdaUtils
import Collections

public extension Entity {
    /// Hold entity components specific for entity.
    struct ComponentSet: Codable, Sendable {
        @_spi(Internal)
        public var entity: Entity.ID

        // Reference to world.
        weak var world: World? {
            didSet {
                self.notFlushedComponents.removeAll()
            }
        }

        /// Components that are not flushed to the world.
        private(set) var notFlushedComponents: SparseSet<ComponentId, any Component> = [:]

        // MARK: - Codable
        
        /// Create an empty component set.
        init(entity: Entity.ID) {
            self.entity = entity
        }

        /// Create a component set from another component set.
        /// - Parameter other: The other component set to create a component set from.
        init(from other: borrowing Self) {
            self.entity = other.entity
            self.notFlushedComponents = other.notFlushedComponents
        }
        
        /// Create component set from decoder.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            self.entity = -1

            for key in container.allKeys {
                guard let type = ComponentStorage.getRegisteredComponent(for: key.stringValue)
                else {
                    continue
                }

                if let decodable = type as? Decodable.Type {
                    let component = try decodable.init(from: container.superDecoder(forKey: key))
                    self.notFlushedComponents[type.identifier] = component as? Component
                }
            }
        }
        
        /// Encode the component set to an encoder.
        /// - Parameter encoder: The encoder to encode the component set to.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            guard let world else {
                throw CodableError.worldIsNil
            }
            guard let location = world.entities.entities[entity] else {
                throw CodableError.entityNotFoundInWorld
            }

            let chunk = world.archetypes
                .archetypes[location.archetypeId]
                .chunks.chunks[location.chunkIndex]
            let components = chunk.getComponents(for: entity)
            for (_, component) in components {
                do {
                    try container.encode(
                        AnyEncodable(component),
                        forKey: CodingName(stringValue: type(of: component).swiftName)
                    )
                } catch {
                    // TODO: Logging
                    print("Component encoding error: \(error)")
                }
            }
        }

        /// Gets or sets the component of the specified type.
        @inline(__always)
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            _read {
                yield get(for: T.self)
            }
            set {
                if let newValue {
                    self.insert(newValue)
                } else {
                    self.remove(T.self)
                }
            }
        }

        // FIXME: Replace to subscript??

        /// Get any count of component types from set.
        @inline(__always)
        public func get<each T: Component>(_ type: repeat (each T).Type) -> (repeat each T) {
            return (repeat get(for: (each T).self)!)
        }

        public func get<T: Component>(for type: T.Type) -> T? {
            if let world {
                world.get(from: entity)
            } else {
                notFlushedComponents[T.identifier] as? T
            }
        }

        /// Set the component of the specified type.
        @inline(__always)
        public mutating func insert<T>(_ component: consuming T) where T : Component {
            guard let world else {
                self.notFlushedComponents[T.identifier] = component
                return
            }
            world.insert(component, for: entity)
        }

        /// Set the components of the specified type.
        @inline(__always)
        public mutating func insert<each T: Component>(_ components: consuming (repeat (each T))) {
            for component in repeat (each components) {
                self.insert(component)
            }
        }

        /// Set the components of the specified type using ``ComponentsBuilder``.
        public mutating func insert(@ComponentsBuilder components: () -> [Component]) {
            let components = components()
            for component in components {
                self.insert(component)
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return has(componentType.identifier)
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentId: ComponentId) -> Bool {
            guard let world else {
                return self.notFlushedComponents.contains(componentId)
            }
            return world.has(componentId, in: entity)
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            guard let world else {
                self.notFlushedComponents.remove(for: componentType.identifier)
                return
            }
            world.remove(componentType.identifier, from: entity)
        }
        
        /// The number of components in the set.
        public var count: Int {
            guard
                let world,
                let location = world.entities.entities[entity]
            else {
                return self.notFlushedComponents.count
            }
            return world.archetypes
                .archetypes[location.archetypeId]
                .chunks.chunks[location.chunkIndex]
                .getComponents(for: entity)
                .count
        }
        
        /// A Boolean value indicating whether the set is empty.
        public var isEmpty: Bool {
            return count == 0
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
            get(for: A.self)!,
            get(for: B.self)!
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
            get(for: A.self)!,
            get(for: B.self)!,
            get(for: C.self)!
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
            get(for: A.self)!,
            get(for: B.self)!,
            get(for: C.self)!,
            get(for: D.self)!
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
        guard let world else {
            return "ComponentSet(entity: \(entity), world: nil)"
        }
        guard let location = world.entities.entities[entity] else {
            return "ComponentSet(entity: \(entity), world: \(world))"
        }

        let chunk = world.archetypes
            .archetypes[location.archetypeId]
            .chunks.chunks[location.chunkIndex]
        let components = chunk.getComponents(for: entity)
        let result = components.reduce("") { partialResult, value in
            let name = type(of: value.1)
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
        if let world {
            world.get(T.self, from: entity)
        } else {
            notFlushedComponents[identifier] as? T
        }
    }
    
    /// Get a component by its identifier.
    /// - Parameter componentId: The identifier of the component.
    /// - Returns: The component if it exists, otherwise nil.
    subscript<T: Component>(by componentId: ComponentId) -> T? {
        _read {
            yield get(T.self)
        }
        set {
            if let newValue {
                self.insert(newValue)
            } else {
                self.remove(T.self)
            }
        }
    }
}

private extension Entity {
    enum CodableError: Error {
        case worldIsNil
        case entityNotFoundInWorld
    }
}

// swiftlint:enable identifier_name
