//
//  ManagedArrayTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.10.2025.
//

import Testing
@testable import AdaUtils

@Suite
struct ManagedArrayTests {
    
    @Test("Initialize empty ManagedArray")
    func testInitEmptyArray() {
        let array = ManagedArray<Int>()
        #expect(array.count == 0)
        #expect(array.startIndex == 0)
        #expect(array.endIndex == 0)
    }
    
    @Test("Initialize ManagedArray with capacity")
    func testInitWithCapacity() {
        let array = ManagedArray<Int>(count: 16)
        #expect(array.count == 0)
        #expect(array.startIndex == 0)
        #expect(array.endIndex == 0)
    }
    
    @Test("Append elements to ManagedArray")
    func testAppendElements() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        #expect(array.count == 3)
        #expect(array.endIndex == 3)
        
        // Verify elements using reborrow
        array.reborrow(at: 0) { element in
            #expect(element == 1)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 2)
        }
        array.reborrow(at: 2) { element in
            #expect(element == 3)
        }
    }
    
    @Test("Insert elements at specific positions")
    func testInsertElements() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(3)
        array.insert(2, at: 1)
        
        #expect(array.count == 3)
        
        array.reborrow(at: 0) { element in
            #expect(element == 1)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 2)
        }
        array.reborrow(at: 2) { element in
            #expect(element == 3)
        }
    }
    
    @Test("Insert element at beginning")
    func testInsertAtBeginning() {
        var array = ManagedArray<Int>()
        array.append(2)
        array.append(3)
        array.insert(1, at: 0)
        
        #expect(array.count == 3)
        
        array.reborrow(at: 0) { element in
            #expect(element == 1)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 2)
        }
        array.reborrow(at: 2) { element in
            #expect(element == 3)
        }
    }
    
    @Test("Remove element from ManagedArray")
    func testRemoveElement() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        let removed = array.remove(at: 1)
        #expect(removed == 2)
        #expect(array.count == 2)
        
        array.reborrow(at: 0) { element in
            #expect(element == 1)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 3)
        }
    }
    
    @Test("Remove first element")
    func testRemoveFirstElement() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        let removed = array.remove(at: 0)
        #expect(removed == 1)
        #expect(array.count == 2)
        
        array.reborrow(at: 0) { element in
            #expect(element == 2)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 3)
        }
    }
    
    @Test("Remove last element")
    func testRemoveLastElement() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        let removed = array.remove(at: 2)
        #expect(removed == 3)
        #expect(array.count == 2)
        
        array.reborrow(at: 0) { element in
            #expect(element == 1)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 2)
        }
    }
    
    @Test("forEach iterates over all elements")
    func testForEach() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        var sum = 0
        array.forEach { element in
            sum += element
        }
        
        #expect(sum == 6)
    }
    
    @Test("map transforms all elements")
    func testMap() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        let doubled = array.map { $0 * 2 }
        #expect(doubled == [2, 4, 6])
    }
    
    @Test("Capacity increases when needed")
    func testCapacityIncrease() {
        var array = ManagedArray<Int>()
        
        // Default capacity is 8, add 9 elements to trigger capacity increase
        for i in 1...9 {
            array.append(i)
        }
        
        #expect(array.count == 9)
        
        // Verify all elements are intact
        for i in 0..<9 {
            array.reborrow(at: i) { element in
                #expect(element == i + 1)
            }
        }
    }
    
    @Test("Append many elements")
    func testAppendManyElements() {
        var array = ManagedArray<Int>()
        
        for i in 1...100 {
            array.append(i)
        }
        
        #expect(array.count == 100)
        
        // Verify a few elements
        array.reborrow(at: 0) { element in
            #expect(element == 1)
        }
        array.reborrow(at: 49) { element in
            #expect(element == 50)
        }
        array.reborrow(at: 99) { element in
            #expect(element == 100)
        }
    }
    
    @Test("reborrow allows mutation")
    func testReborrowMutation() {
        var array = ManagedArray<Int>()
        array.append(1)
        array.append(2)
        array.append(3)
        
        array.reborrow(at: 1) { element in
            element = 10
        }
        
        array.reborrow(at: 1) { element in
            #expect(element == 10)
        }
    }
    
    @Test("Multiple inserts and removes")
    func testMultipleOperations() {
        var array = ManagedArray<Int>()
        
        // Add elements
        array.append(1)
        array.append(2)
        array.append(3)
        #expect(array.count == 3)
        
        // Insert in middle
        array.insert(10, at: 1)
        #expect(array.count == 4)
        
        // Remove first
        let removed = array.remove(at: 0)
        #expect(removed == 1)
        #expect(array.count == 3)
        
        // Verify remaining elements
        array.reborrow(at: 0) { element in
            #expect(element == 10)
        }
        array.reborrow(at: 1) { element in
            #expect(element == 2)
        }
        array.reborrow(at: 2) { element in
            #expect(element == 3)
        }
    }
    
    @Test("Empty array properties")
    func testEmptyArrayProperties() {
        let array = ManagedArray<String>()
        #expect(array.count == 0)
        #expect(array.startIndex == 0)
        #expect(array.endIndex == 0)
    }
    
    @Test("String elements work correctly")
    func testStringElements() {
        var array = ManagedArray<String>()
        array.append("Hello")
        array.append("World")
        array.append("Swift")
        
        #expect(array.count == 3)
        
        let joined = array.map { $0 }.joined(separator: " ")
        #expect(joined == "Hello World Swift")
    }
}
