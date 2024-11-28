//
//  Archetype.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/21/22.
//

struct ComponentId: Hashable, Equatable {
    let id: Int
}

struct EntityRecord {
    // which archetype contains info about an entity
    var archetypeId: Archetype.ID
    
    // index of entity in archetype
    var row: Int
}

/// Types for defining Archetypes, collections of entities that have the same set of
/// components.
public final class Archetype: Hashable, Identifiable {
    public let id: Int
    public internal(set) var entities: SparseArray<Entity> = []
    
    @usableFromInline
    private(set) var friedEntities: [Int] = []
    
    var edge: Edge = Edge()
    var componentsBitMask: BitSet = BitSet()
    
    private init(id: Archetype.ID, entities: [Entity] = [], componentsBitMask: BitSet = BitSet()) {
        self.id = id
        self.entities = SparseArray(entities)
        self.componentsBitMask = componentsBitMask
        self.friedEntities.reserveCapacity(30)
    }
    
    @inline(__always)
    static func new(index: Int) -> Archetype {
        return Archetype(id: index)
    }
    
    @inline(__always)
    func append(_ entity: Entity) -> EntityRecord {
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
    
    @inline(__always)
    func remove(at index: Int) {
        self.entities.remove(at: index)
        self.friedEntities.append(index)
    }
    
    @inline(__always)
    func clear() {
        self.componentsBitMask = BitSet()
        self.friedEntities.removeAll()
        self.entities.removeAll()
        self.edge = Edge()
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(componentsBitMask)
        hasher.combine(entities)
    }
    
    public static func == (lhs: Archetype, rhs: Archetype) -> Bool {
        return lhs.entities == rhs.entities &&
        lhs.id == rhs.id && lhs.componentsBitMask == rhs.componentsBitMask
    }
}

extension Archetype: CustomStringConvertible {
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
    struct Edge: Hashable, Equatable {
        var add: [ComponentId : Archetype] = [:]
        var remove: [ComponentId : Archetype] = [:]
    }
}

// FIXME: (Vlad) not a bit set!
struct BitSet: Equatable, Hashable {
    // TODO: (Vlad) Not efficient in memory layout.
    private var mask: Set<ComponentId>

    init(reservingCapacity: Int = 0) {
        self.mask = []
        self.mask.reserveCapacity(reservingCapacity)
    }
    
    mutating func insert<T: Component>(_ component: T.Type) {
        self.mask.insert(T.identifier)
    }

    mutating func insert(_ component: ComponentId) {
        self.mask.insert(component)
    }

    mutating func remove<T: Component>(_ component: T.Type) {
        self.mask.remove(T.identifier)
    }

    func contains(_ identifier: ComponentId) -> Bool {
        self.mask.contains(identifier)
    }

    func contains<T: Component>(_ component: T.Type) -> Bool {
        return self.mask.contains(T.identifier)
    }
}
