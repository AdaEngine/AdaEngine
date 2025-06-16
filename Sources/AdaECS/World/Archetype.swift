//
//  Archetype.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/21/22.
//

import AdaUtils
import Foundation

/// The unique identifier of the component.
public struct ComponentId: Hashable, Equatable, Sendable {
    /// The unique identifier of the component.
    let id: Int
}

public struct EntityLocation: Sendable, Hashable {
    public let archetypeId: Archetype.ID
    public let archetypeRow: Int
    public let chunkIndex: Int
    public let chunkRow: Int
}

public struct Entities: Sendable {
    public var entities: [Entity.ID: EntityLocation] = [:]
}

public struct Archetypes: Sendable {
    public var componentsIndex: [BitSet: Archetype.ID]
    public var archetypes: [Archetype]

    public init(
        componentsIndex: [BitSet: Archetype.ID] = [:],
        archetypes: [Archetype] = []
    ) {
        let emptyArchetype = Archetype.new(index: 0, componentLayout: ComponentLayout(components: []))
        self.componentsIndex = [BitSet(): emptyArchetype.id]
        self.archetypes = [emptyArchetype]
    }

    public mutating func getOrCreate(for componentLayout: ComponentLayout) -> Archetype.ID {
        if let archetypeIndex = self.componentsIndex[componentLayout.bitSet] {
            return archetypeIndex
        }

        let newIndex = archetypes.count
        let archetype = Archetype.new(index: newIndex, componentLayout: componentLayout)
        self.archetypes.append(archetype)
        componentsIndex[componentLayout.bitSet] = newIndex
        return newIndex
    }

    public mutating func clear() {
        self.archetypes.removeAll(keepingCapacity: true)
        self.componentsIndex.removeAll(keepingCapacity: true)
    }
}

public struct ComponentLayout: Hashable, Sendable {
    public private(set) var components: [any Component.Type]
    public private(set) var bitSet: BitSet

    public init(components: [any Component]) {
        var componentTypes = [any Component.Type]()
        var bitSet = BitSet(reservingCapacity: components.count)
        for component in components {
            let componentType = type(of: component)
            componentTypes.append(componentType)
            bitSet.insert(componentType.identifier)
        }
        self.bitSet = bitSet
        self.components = componentTypes
    }

    public init<each T: Component>(components: repeat each T) {
        var components = [any Component.Type]()
        var bitSet = BitSet()
        for component in repeat (each T).self {
            let id = component.identifier
            components.append(component)
            bitSet.insert(id)
        }
        self.components = components
        self.bitSet = bitSet
    }

    public mutating func insert<T: Component>(_ component: T.Type) {
        self.bitSet.insert(component)
        self.components.append(component)
    }

    public mutating func remove(_ component: ComponentId) {
        self.bitSet.remove(component)
        self.components.removeAll { $0.identifier == component }
    }

    public static func == (lhs: ComponentLayout, rhs: ComponentLayout) -> Bool {
        lhs.bitSet == rhs.bitSet
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.bitSet)
    }
}

/// Types for defining Archetypes, collections of entities that have the same set of
/// components.
public struct Archetype: Hashable, Identifiable, Sendable {
    /// The unique identifier of the archetype.
    public let id: Int

    public internal(set) var chunks: Chunks

    /// The entities in the archetype.
    public internal(set) var entities: SparseArray<Entity> = []

    /// The fried entities in the archetype.
    @usableFromInline
    private(set) var friedEntities: [Int] = []
    
    /// The edge of the archetype.
    var edges: Edges = Edges()

    /// The components bit mask of the archetype.
    public internal(set) var componentLayout: ComponentLayout

    /// Initialize a new archetype.
    /// - Parameter id: The unique identifier of the archetype.
    /// - Parameter entities: The entities in the archetype.
    private init(
        id: Archetype.ID,
        entities: [Entity] = [],
        componentLayout: ComponentLayout
    ) {
        self.id = id
        self.entities = SparseArray(entities)
        self.componentLayout = componentLayout
        self.chunks = Chunks(componentLayout: componentLayout)
        self.friedEntities.reserveCapacity(32)
    }
    
    /// Create a new archetype.
    /// - Parameter index: The index of the archetype.
    /// - Returns: A new archetype.
    @inline(__always)
    static func new(index: Int, componentLayout: ComponentLayout) -> Archetype {
        return Archetype(id: index, componentLayout: componentLayout)
    }
    
    /// Append an entity to the archetype.
    /// - Parameter entity: The entity to append.
    /// - Returns: The record of the entity.
    @inline(__always)
    mutating func append(_ entity: consuming Entity) -> Int {
        if !friedEntities.isEmpty {
            let index = self.friedEntities.removeLast()
            self.entities.insert(entity, at: index)
            return index
        } else {
            self.entities.append(entity)
            return self.entities.count - 1
        }
    }
    
    /// Remove an entity from the archetype.
    /// - Parameter index: The index of the entity to remove.
    @inline(__always)
    mutating func remove(at index: Int) {
        self.entities.remove(at: index)
        self.friedEntities.append(index)
    }
    
    /// Clear the archetype.
    @inline(__always)
    mutating func clear() {
        self.friedEntities.removeAll()
        self.entities.removeAll()
        self.edges = Edges()
    }
    
    // MARK: - Hashable
    
    /// Hash the archetype.
    /// - Parameter hasher: The hasher to hash the archetype.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(componentLayout)
        hasher.combine(entities)
    }
    
    /// Check if two archetypes are equal.
    /// - Parameter lhs: The left archetype.
    /// - Parameter rhs: The right archetype.
    /// - Returns: True if the two archetypes are equal, otherwise false.
    public static func == (lhs: Archetype, rhs: Archetype) -> Bool {
        return lhs.entities == rhs.entities &&
        lhs.id == rhs.id && lhs.componentLayout == rhs.componentLayout
    }
}

extension Archetype: CustomStringConvertible {
    /// The description of the archetype.
    public var description: String {
        """
        Archetype(
            id: \(id)
            entityIds: \(entities.compactMap { $0.id })
            componentsLayout: \(componentLayout)
        )
        """
    }
}

extension Archetype {
    /// The edges of the archetype.
    struct Edges: Hashable, Sendable {
        /// The components to add.
        private var add: [ComponentLayout: Archetype.ID] = [:]

        /// The components to remove.
        private var remove: [ComponentLayout: Archetype.ID] = [:]

        @inline(__always)
        mutating func addArchetypeAfterInsertion(
            _ archetype: Archetype.ID,
            for layout: ComponentLayout
        ) {
            self.add[layout] = archetype
        }

        @inline(__always)
        mutating func addArchetypeAfterRemoval(
            _ archetype: Archetype.ID,
            for layout: ComponentLayout
        ) {
            self.remove[layout] = archetype
        }

        @inline(__always)
        mutating func getArchetypeAfterInsertion(
            for layout: ComponentLayout
        ) -> Archetype.ID? {
            self.add[layout]
        }

        @inline(__always)
        mutating func getArchetypeAfterRemoval(
            for layout: ComponentLayout
        ) -> Archetype.ID? {
            self.remove[layout]
        }
    }
}

//// FIXME: (Vlad) not a bit set!
public struct BitSet: Hashable, Sendable {
    // TODO: (Vlad) Not efficient in memory layout.
    private var mask: Set<ComponentId>

    var isEmpty: Bool {
        return self.mask.isEmpty
    }

    init(reservingCapacity: Int = 0) {
        self.mask = []
        self.mask.reserveCapacity(reservingCapacity)
    }

    mutating func insert<T: Component>(_ component: T.Type) {
        self.mask.insert(T.identifier)
    }

    mutating func insert(_ component: consuming ComponentId) {
        self.mask.insert(component)
    }

    mutating func remove<T: Component>(_ component: T.Type) {
        self.mask.remove(T.identifier)
    }

    mutating func remove(_ componentId: ComponentId) {
        self.mask.remove(componentId)
    }

    public func contains(_ identifier: consuming ComponentId) -> Bool {
        self.mask.contains(identifier)
    }

    func contains<T: Component>(_ component: T.Type) -> Bool {
        return self.mask.contains(T.identifier)
    }
}
