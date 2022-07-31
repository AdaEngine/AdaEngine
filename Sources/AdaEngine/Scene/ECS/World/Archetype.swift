//
//  Archetype.swift
//  
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

public final class Archetype: Hashable, Identifiable {
    
    public let id: Int
    public internal(set) var entities: [Entity?] = []
    private(set) var friedEntities: [Int] = []
    var edge: Edge = Edge()
    var componentsBitMask: Bitset = Bitset()
    
    private init(id: Archetype.ID, entities: [Entity] = [], componentsBitMask: Bitset = Bitset()) {
        self.id = id
        self.entities = entities
        self.componentsBitMask = componentsBitMask
    }
    
    static func new(index: Int) -> Archetype {
        return Archetype(id: index)
    }
    
    func append(_ entity: Entity) -> EntityRecord {
        
        let row: Int
        
        if !friedEntities.isEmpty {
            let index = self.friedEntities.removeFirst()
            self.entities[index] = entity
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
    
    func remove(at index: Int) {
        self.entities[index] = nil
        
        self.friedEntities.append(index)
    }
    
    func clear() {
        self.componentsBitMask.clear()
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
            entityIds: \(entities.compactMap { $0?.id })
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

struct Bitset: Equatable, Hashable {
    // TODO: Not efficient in memory layout.
    private var mask: Set<ComponentId>
    
    init(count: Int = 0) {
        self.mask = []
        self.mask.reserveCapacity(count)
    }
    
    mutating func insert<T: Component>(_ component: T.Type) {
        self.mask.insert(T.identifier)
    }
    
    mutating func remove<T: Component>(_ component: T.Type) {
        self.mask.remove(T.identifier)
    }
    
    func contains<T: Component>(_ component: T.Type) -> Bool {
        return self.mask.contains(T.identifier)
    }
    
    func contains(_ identifier: ComponentId) -> Bool {
        return self.mask.contains(identifier)
    }
    
    mutating func clear() {
        self.mask.removeAll()
    }
    
    // MARK: Unsafe
    
    mutating func insert(_ component: ComponentId) {
        self.mask.insert(component)
    }
    
    func contains(_ bitmask: Bitset) -> Bool {
        return bitmask.mask == self.mask
    }
}
