//
//  Archetype.swift
//  
//
//  Created by v.prusakov on 6/21/22.
//

struct Archetype: Hashable, Equatable {
    let id: UInt16
}

class World {
    private var entities: [Entity] = []
    private var archetypes: [Archetype] = []
}
