//
//  Chunks.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2025.
//

public struct Chunks: Sendable {
    public var chunks: [Chunk] = []

    public let chunkSize: UInt8

    public init(chunkSize: UInt8 = 1) {
        self.chunkSize = chunkSize
    }
}

public struct TableColumn: Sendable {
    public 
}

public struct Table: Sendable {
    public var components: [TableColumn]
    public var componentsIndecies: [ComponentId: Int]
}

public struct Chunk: Sendable {
    public let capacity: Int
    public var entities: [EntityRecord]
    public var components: [any Component]
    public var componentsIndecies: [Int]
    public var bitSet: BitSet

    init(capacity: Int, entities: [EntityRecord], components: [any Component], componentsIndecies: [Int]) {
        self.capacity = capacity
        self.entities = entities
        self.components = components
        self.componentsIndecies = componentsIndecies
        self.bitSet = BitSet()
    }
}
