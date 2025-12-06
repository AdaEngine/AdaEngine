//
//  SparseSetTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 15.11.2025.
//

import AdaUtils
import Testing

@Suite
struct SparseSetTests {
    @Test func `getting value from set returns correctly`() {
        var sparseSet = SparseSet<Int, String>()
        sparseSet[0] = "0"
        sparseSet[1] = "1"
        sparseSet[2] = "2"
        sparseSet[3] = "3"

        #expect(sparseSet.count == 4)
        #expect(sparseSet[0] == "0")
        #expect(sparseSet[1] == "1")
        #expect(sparseSet[2] == "2")
        #expect(sparseSet[3] == "3")
    }

    @Test func `iterator works as plain array`() {
        var sparseSet = SparseSet<Int, String>()
        sparseSet[0] = "0"
        sparseSet[1] = "1"
        sparseSet[2] = "2"
        sparseSet[3] = "3"

        var expectedArray = ["0", "1", "2", "3"]

        for value in sparseSet {
            #expect(expectedArray.removeFirst() == value)
        }

        #expect(expectedArray.isEmpty == true)
    }

    @Test func `remove element works as expected`() {
        var sparseSet = SparseSet<Int, String>()
        sparseSet[0] = "0"
        sparseSet[1] = "1"
        sparseSet[2] = "2"
        sparseSet[3] = "3"

        #expect(sparseSet.count == 4)
        var expectedArray = ["0", "1", "3"]
        sparseSet.remove(for: 2)

        #expect(sparseSet.count == 3)

        for value in sparseSet {
            #expect(expectedArray.removeFirst() == value)
        }
        
        #expect(expectedArray.isEmpty == true)
    }

    @Test func `remove non existing element return nil`() {
        var sparseSet = SparseSet<Int, String>()
        sparseSet[0] = "0"
        sparseSet[1] = "1"
        sparseSet[2] = "2"
        sparseSet[3] = "3"
        #expect(sparseSet.count == 4)

        let value = sparseSet.remove(for: 9)
        #expect(value == nil)
        #expect(sparseSet.count == 4)
    }
}
