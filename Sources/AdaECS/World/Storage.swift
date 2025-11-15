//
//  Storage.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 14.11.2025.
//

import AdaUtils

struct Storage: Sendable {
    
}

struct Tables: Sendable {
    var tables: ContiguousArray<Table>
    var tableIds: [ComponentLayout: Int] = [:]
}

struct Table: Sendable {
    var entities: ContiguousArray<Entity> = []
}
