//
//  SparseArrayTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 04.11.2025.
//

@testable import AdaUtils
import Testing

@Suite
struct SparseArrayTests {
    @Test
    func `init with capacity contains same count of allocated elements`() throws {
        let array = SparseArray<Int>(capacity: 30)
        #expect(array.isEmpty == true)
        #expect(array.count == 0)
        #expect(array.underestimatedCount == 30)
    }

    @Test
    func `init with sequence contains same count of allocated elements`() throws {
        let array = SparseArray<Int>([10, 20, 40])
        #expect(array.isEmpty == false)
        #expect(array.count == 3)
        #expect(array.underestimatedCount == 3)
    }

    @Test
    func `allocation with literal`() throws {
        let array: SparseArray<Int> = [10, 20, 30]
        #expect(array.isEmpty == false)
        #expect(array.count == 3)
        #expect(array.underestimatedCount == 3)
    }

    @Test
    func `remove all with keepingCapacity contains same count of allocated elements`() throws {
        var array = SparseArray<Int>(capacity: 30)
        #expect(array.isEmpty == true)
        #expect(array.count == 0)
        #expect(array.underestimatedCount == 30)

        array.removeAll(keepingCapacity: true)

        #expect(array.isEmpty == true)
        #expect(array.count == 0)
        #expect(array.underestimatedCount == 30)
    }

    @Test
    func `remove all without keepingCapacity is empty`() throws {
        var array = SparseArray<Int>(capacity: 30)
        #expect(array.isEmpty == true)
        #expect(array.count == 0)
        #expect(array.underestimatedCount == 30)

        array.removeAll(keepingCapacity: false)

        #expect(array.isEmpty == true)
        #expect(array.count == 0)
        #expect(array.underestimatedCount == 0)
    }

    @Test
    func `remove at index replace value by nil`() throws {
        var array = SparseArray<Int>([10, 20, 30])
        let value = array.remove(at: 1)
        #expect(value == 20)
        #expect(array.values[1] == nil)
        #expect(array.count == 2)
        #expect(array.underestimatedCount == 3)
    }

    @Test
    func `remove last returns value and replace last by nil`() throws {
        var array = SparseArray<Int>([10, 20, 30, 40])
        let value = array.remove(at: 3)
        #expect(value == 40)

        let removedLast = array.removeLast()

        // should be [10, 20, nil, nil]
        #expect(removedLast == 30)
        #expect(array.values[2] == nil)
        #expect(array.count == 2)
        #expect(array.underestimatedCount == 4)
    }

    @Test
    func `insert element at index works properly`() throws {
        var array = SparseArray<Int>([10, 20, 30, 40])
        array.insert(50, at: 1)
        #expect(array.values == [10, 50, 30, 40])
    }

    @Test
    func `append element works properly`() throws {
        var array = SparseArray<Int>([10, 20, 30, 40])
        array.append(50)
        #expect(array.values == [10, 20, 30, 40, 50])
        #expect(array.isEmpty == false)
        #expect(array.count == 5)
        #expect(array.underestimatedCount == 5)
    }

    @Test
    func `iterator never returns nil values`() async throws {
        var array = SparseArray<Int>([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        array.remove(at: 1)
        array.remove(at: 5)
        array.remove(at: 9)

        var expectedSequence = [1, 3, 4, 5, 7, 8, 9]
        #expect(array.count == expectedSequence.count)
        #expect(array.underestimatedCount == 10)

        for element in array {
            #expect(expectedSequence.removeFirst() == element)
        }
        #expect(expectedSequence.count == 0)
    }
}
