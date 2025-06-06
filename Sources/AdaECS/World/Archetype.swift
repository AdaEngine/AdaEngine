//
//  Archetype.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/21/22.
//

import AdaUtils

/// The unique identifier of the component.
public struct ComponentId: Hashable, Equatable, Sendable {
    /// The unique identifier of the component.
    let id: Int
}

/// The record of the entity.
struct EntityRecord: Sendable {
    /// The unique identifier of the archetype that contains the entity.
    var archetypeId: Archetype.ID
    
    /// The index of the entity in the archetype.
    var row: Int
}

/// Types for defining Archetypes, collections of entities that have the same set of
/// components.
public struct Archetype: Hashable, Identifiable, Sendable {
    /// The unique identifier of the archetype.
    public let id: Int

    /// The entities in the archetype.
    public internal(set) var entities: SparseArray<Entity> = []

    /// The components in the archetype.
    public internal(set) var components: [ComponentId: any Component] = [:]

    /// The fried entities in the archetype.
    @usableFromInline
    private(set) var friedEntities: [Int] = []
    
    /// The edge of the archetype.
    var edge: Edge = Edge()

    /// The components bit mask of the archetype.
    public internal(set) var componentsBitMask: BitSet = BitSet()

    /// Initialize a new archetype.
    /// - Parameter id: The unique identifier of the archetype.
    /// - Parameter entities: The entities in the archetype.
    private init(
        id: Archetype.ID,
        entities: [Entity] = [],
        componentsBitMask: BitSet = BitSet()
    ) {
        self.id = id
        self.entities = SparseArray(entities)
        self.componentsBitMask = componentsBitMask
        self.friedEntities.reserveCapacity(30)
    }
    
    /// Create a new archetype.
    /// - Parameter index: The index of the archetype.
    /// - Returns: A new archetype.
    @inline(__always)
    static func new(index: Int) -> Archetype {
        return Archetype(id: index)
    }
    
    /// Append an entity to the archetype.
    /// - Parameter entity: The entity to append.
    /// - Returns: The record of the entity.
    @inline(__always)
    mutating func append(_ entity: consuming Entity) -> EntityRecord {
        let row: Int
        
        if !friedEntities.isEmpty {
            let index = self.friedEntities.removeLast()
            self.entities.insert(entity, at: index)
            row = index
        } else {
            self.entities.append(entity)
            row = self.entities.count - 1
        }
        
        return EntityRecord(
            archetypeId: self.id,
            row: row
        )
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
        self.componentsBitMask = BitSet()
        self.friedEntities.removeAll()
        self.entities.removeAll()
        self.edge = Edge()
    }
    
    // MARK: - Hashable
    
    /// Hash the archetype.
    /// - Parameter hasher: The hasher to hash the archetype.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(componentsBitMask)
        hasher.combine(entities)
    }
    
    /// Check if two archetypes are equal.
    /// - Parameter lhs: The left archetype.
    /// - Parameter rhs: The right archetype.
    /// - Returns: True if the two archetypes are equal, otherwise false.
    public static func == (lhs: Archetype, rhs: Archetype) -> Bool {
        return lhs.entities == rhs.entities &&
        lhs.id == rhs.id && lhs.componentsBitMask == rhs.componentsBitMask
    }
}

extension Archetype: CustomStringConvertible {
    /// The description of the archetype.
    public var description: String {
        """
        Archetype(
            id: \(id)
            entityIds: \(entities.compactMap { $0.id })
            componentsBitMask: \(componentsBitMask)
        )
        """
    }
}

extension Archetype {
    /// The edge of the archetype.
    struct Edge: Hashable, Equatable, Sendable {
        /// The components to add.
        var add: [ComponentId : Archetype] = [:]

        /// The components to remove.
        var remove: [ComponentId : Archetype] = [:]
    }
}

//// FIXME: (Vlad) not a bit set!
public struct BitSet: Equatable, Hashable, Sendable {
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

    public func contains(_ identifier: consuming ComponentId) -> Bool {
        self.mask.contains(identifier)
    }

    func contains<T: Component>(_ component: T.Type) -> Bool {
        return self.mask.contains(T.identifier)
    }
}
