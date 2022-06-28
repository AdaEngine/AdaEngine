//
//  Archetype.swift
//  
//
//  Created by v.prusakov on 6/21/22.
//

final class Archetype: Hashable {
    typealias ID = UInt16
    
    let id: ID
    var entities: [Entity] = []
    var edges: [Edge] = []
    var componentsBitMask: BitMask = BitMask()
    
    private init(id: Archetype.ID, entities: [Entity] = [], edges: [Archetype.Edge] = [], componentsBitMask: Archetype.BitMask = BitMask()) {
        self.id = id
        self.entities = entities
        self.edges = edges
        self.componentsBitMask = componentsBitMask
    }
    
    static var identifier: UInt16 = 0
    
    static func new() -> Archetype {
        defer { self.identifier += 1 }
        return Archetype(id: self.identifier)
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(componentsBitMask)
        hasher.combine(entities)
    }
    
    static func == (lhs: Archetype, rhs: Archetype) -> Bool {
        return lhs.entities == rhs.entities &&
        lhs.id == rhs.id && lhs.componentsBitMask == rhs.componentsBitMask
    }
}

extension Archetype: CustomStringConvertible {
    var description: String {
        """
        Archetype(
            id: \(id)
            entityIds: \(entities.map { $0.id })
            componentsBitMask: \(componentsBitMask)
        )
        """
    }
}

extension Archetype {
    struct Edge: Hashable, Equatable {
        var add: [Archetype.ID : Archetype] = [:]
        var remove: [Archetype.ID : Archetype] = [:]
    }
}

extension Archetype {
    static let empty = Archetype(id: 0)
    static let invalud = Archetype(id: .max)
}

extension Archetype {
    struct BitMask: Equatable, Hashable {
        private var mask: Set<UInt>
        
        init(count: Int = 0) {
            self.mask = []
            self.mask.reserveCapacity(count)
        }
        
        mutating func add<T: Component>(_ component: T.Type) {
            self.mask.insert(T.identifier)
        }
        
        mutating func remove<T: Component>(_ component: T.Type) {
            self.mask.remove(T.identifier)
        }
        
        func contains<T: Component>(_ component: T.Type) -> Bool {
            return self.mask.contains(T.identifier)
        }
        
        func contains(_ identifier: UInt) -> Bool {
            return self.mask.contains(identifier)
        }
        
        // MARK: Unsafe
        
        mutating func add(_ component: UInt) {
            self.mask.insert(component)
        }
        
        func contains(_ bitmask: BitMask) -> Bool {
            return bitmask.mask == self.mask
        }
    }
}
