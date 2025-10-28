//
//  ChunkTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.10.2025.
//

@testable import AdaECS
import Testing
import Foundation

@Component
private struct A: Equatable {
    let a: Int
    let b: Bool
    let c: String

    init() {
        self.a = .random(in: 0..<100)
        self.b = .random()
        self.c =  UUID().uuidString
    }
}

@Component
private struct B: Equatable {
    let a: String
    let b: String
    let c: Bool
    let d: Int

    init() {
        self.a = UUID().uuidString
        self.b = UUID().uuidString
        self.c = .random()
        self.d = .random(in: 0..<100)
    }
}

//@Suite("Chunks Tests")
//struct ChunksTests {
//    var chunks: Chunks
//
//    init() {
//        self.chunks = Chunks(
//            chunkSize: 32,
//            componentLayout: ComponentLayout(
//                componentTypes: [
//                    A.self,
//                    B.self
//                ]
//            )
//        )
//    }
//
//    @Test
//    mutating func `inserted value returns correctly`() throws {
//        let a = A()
//        let b = B()
//        let location = chunks.insertEntity(1, components: [a, b])
//
//        #expect(chunks.entities.count == 1)
//        #expect(
//            chunks.chunks.reborrow(at: location.chunkIndex, { chunk in
//                chunk.get(A.self, for: location.entityRow) == a
//            })
//        )
//        #expect(
//            chunks.chunks.reborrow(at: location.chunkIndex, { chunk in
//                chunk.get(B.self, for: location.entityRow) == b
//            })
//        )
//    }
//}

@Suite("Chunk Tests")
struct ChunkTests {
    @Test
    func `inserted entity in chunk returns correctly`() throws {
        var chunk = Chunk(
            capacity: 32,
            layout: ComponentLayout(
                componentTypes: [
                    A.self,
                    B.self
                ]
            )
        )
        let a = A()
        let b = B()
        let rowId = chunk.addEntity(1)!
        chunk.insert(at: rowId, components: [a, b])
        #expect(chunk.isOccupied(at: rowId) == true)
        #expect(chunk.entityCount == 1)
        #expect(chunk.get(A.self, for: 1) == a)
        #expect(chunk.get(B.self, for: 1) == b)
    }

    @Test
    func `removed entity in chunk returns correctly`() throws {
        var chunk = Chunk(
            capacity: 32,
            layout: ComponentLayout(
                componentTypes: [
                    A.self,
                    B.self
                ]
            )
        )
        let rowId = chunk.addEntity(1)!
        chunk.insert(at: rowId, components: [A(), B()])
        chunk.removeEntity(at: 1)
        #expect(chunk.isOccupied(at: rowId) == false)
        #expect(chunk.get(A.self, for: 1) == nil)
        #expect(chunk.get(B.self, for: 1) == nil)
        #expect(chunk.entityCount == 0)
    }

    @Test
    func `updated components returns correctly`() throws {
        var chunk = Chunk(
            capacity: 32,
            layout: ComponentLayout(
                componentTypes: [
                    A.self,
                    B.self
                ]
            )
        )
        let a = A()
        let newA = A()
        let rowId = chunk.addEntity(1)!
        chunk.insert(at: rowId, components: [a, B()])
        #expect(a != newA)
        #expect(chunk.get(A.self, for: 1) == a)

        chunk.getMutablePointer(A.self, for: 1)?.pointee = newA
        #expect(chunk.get(A.self, for: 1) == newA)
    }

    @Test
    func `filled chunk correctly`() {
        let capacity = 128
        var chunk = Chunk(
            capacity: capacity,
            layout: ComponentLayout(
                componentTypes: [
                    A.self,
                    B.self
                ]
            )
        )

        for index in 0..<capacity {
            let row = chunk.addEntity(index)!
            chunk.insert(at: row, components: [A(), B()])
        }
        #expect(chunk.entityCount == capacity)
        #expect(chunk.isFull == true)
        #expect(chunk.entities.count == capacity)
    }

    @Test
    func `clear chunk works correctly`() {
        let capacity = 128
        var chunk = Chunk(
            capacity: capacity,
            layout: ComponentLayout(
                componentTypes: [
                    A.self,
                    B.self
                ]
            )
        )

        for index in 0..<capacity {
            let row = chunk.addEntity(index)!
            chunk.insert(at: row, components: [A(), B()])
        }
        #expect(chunk.entityCount == capacity)
        #expect(chunk.isFull == true)
        #expect(chunk.entities.count == capacity)
        chunk.clear()
        #expect(chunk.isFull == false)
        #expect(chunk.entityCount == 0)
        #expect(chunk.entities.count == 0)
    }

    @Test
    func `remove entities in different places works correctly`() {
        let capacity = 128
        var chunk = Chunk(
            capacity: capacity,
            layout: ComponentLayout(
                componentTypes: [
                    A.self,
                    B.self
                ]
            )
        )

        for index in 0..<capacity {
            let row = chunk.addEntity(index)!
            chunk.insert(at: row, components: [A(), B()])
        }
        #expect(chunk.entityCount == capacity)
        #expect(chunk.isFull == true)
        #expect(chunk.entities.count == capacity)

        for index in 0..<capacity where index % 2 == 0 {
            chunk.removeEntity(at: index)
        }

        #expect(chunk.entityCount == 64)
        #expect(chunk.isFull == false)
        #expect(chunk.entities.count == 64)
    }
}
