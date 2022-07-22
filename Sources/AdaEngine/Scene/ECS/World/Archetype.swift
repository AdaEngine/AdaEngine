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

//public struct Bitset: Sequence, Hashable {
//
//    public typealias Element = Int
//
//    // We should use buffer to deallocate memory
//    class _Buffer {
//        internal var words: UnsafeMutableBufferPointer<Word>
//
//        internal var wordsCount: Int
//
//        init(capacity: Int) {
//            self.words = UnsafeMutableBufferPointer<Word>.allocate(capacity: capacity)
//            self.wordsCount = 0
//        }
//
//        deinit {
//            words.deallocate()
//        }
//
//        func increaseWordCount(_ count: Int) {
//            let newWords = UnsafeMutableBufferPointer<Word>.allocate(capacity: count)
//            newWords.baseAddress!.moveAssign(from: self.words.baseAddress!, count: self.words.count)
//            self.words.deallocate()
//            self.words = newWords
//        }
//    }
//
//    struct Word {
//        var value: UInt
//
//        init(_ value: UInt) {
//            self.value = value
//        }
//    }
//
//    internal var buffer: _Buffer
//
//    // MARK: Public Methods
//
//    public init(capacity: Int) {
//        self.buffer = _Buffer(capacity: capacity)
//    }
//
//    public init() {
//        self.buffer = _Buffer(capacity: 8)
//    }
//
//    @inline(__always)
//    public var count: Int {
//        return self.buffer.wordsCount
//    }
//
//    public func contains(_ element: Int) -> Bool {
//        let (word, bit) = Self.split(for: element)
//        return buffer.words[word].contains(bit)
//    }
//
//    @discardableResult
//    public mutating func insert(_ element: Int) -> Bool {
//        let (word, bit) = Self.split(for: element)
//
//        if word > buffer.wordsCount {
//            self.buffer.increaseWordCount(word + 1)
//        }
//
//        let isInserted = buffer.words[word].insert(bit)
//        if isInserted {
//            self.buffer.wordsCount += 1
//        }
//
//        return isInserted
//    }
//
//    @discardableResult
//    public mutating func remove(_ element: Int) -> Bool {
//        let (word, bit) = Self.split(for: element)
//        let isRemoved = buffer.words[word].remove(bit)
//        if isRemoved {
//            self.buffer.wordsCount -= 1
//        }
//
//        return isRemoved
//    }
//
//    public mutating func clear() {
//        guard !buffer.words.isEmpty else {
//            return
//        }
//
//        self.buffer.words.baseAddress!.assign(repeating: .empty, count: buffer.wordsCount)
//    }
//
//    // MARK: Sequence
//
//    public struct Iterator: IteratorProtocol {
//
//        let buffer: _Buffer
//        var index: Int
//        var word: Word
//
//        internal init(buffer: _Buffer) {
//            self.buffer = buffer
//            self.index = 0
//            self.word = buffer.wordsCount > 0 ? buffer.words[0] : .empty
//        }
//
//        public mutating func next() -> Int? {
//            if let bit = self.word.next() {
//                return Bitset.join(word: index, bit: bit)
//            }
//            while (index + 1) < buffer.words.count {
//                index += 1
//                word = buffer.words[index]
//                if let bit = word.next() {
//                    return Bitset.join(word: index, bit: bit)
//                }
//            }
//            return nil
//        }
//    }
//
//    public func makeIterator() -> Iterator {
//        return Iterator(buffer: self.buffer)
//    }
//
//    // MARK: Static methods
//
//    static func join(word: Int, bit: Int) -> Int {
//        assert(bit >= 0 && bit < Word.capacity)
//        return word &* Word.capacity &+ bit
//    }
//
//    @inline(__always)
//    static func split(for element: Int) -> (word: Int, bit: Int) {
//        return (word(for: element), bit(for: element))
//    }
//
//    @inline(__always)
//    static func bit(for element: Int) -> Int {
//        assert(element >= 0)
//        // Note: We perform on UInts to get faster unsigned math (masking).
//        let element = UInt(bitPattern: element)
//        let capacity = UInt(bitPattern: Word.capacity)
//        return Int(bitPattern: element % capacity)
//    }
//
//    @inline(__always)
//    static func word(for element: Int) -> Int {
//        assert(element >= 0)
//        // Note: We perform on UInts to get faster unsigned math (shifts).
//        let element = UInt(bitPattern: element)
//        let capacity = UInt(bitPattern: Word.capacity)
//        return Int(bitPattern: element / capacity)
//    }
//
//    // MARK: Hashable
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(self.buffer.wordsCount)
//        hasher.combine(self.buffer.words.baseAddress!.hashValue)
//    }
//
//    public static func == (lhs: Bitset, rhs: Bitset) -> Bool {
//        return lhs.buffer.wordsCount == rhs.buffer.wordsCount && lhs.allSatisfy { rhs.contains($0) }
//    }
//}
//
//extension Bitset.Word {
//
//    @inlinable
//    @inline(__always)
//    var count: Int {
//        return self.value.nonzeroBitCount
//    }
//
//    @inlinable
//    @inline(__always)
//    var isEmpty: Bool {
//        return self.value == 0
//    }
//
//    @inlinable
//    @inline(__always)
//    internal func contains(_ bit: Int) -> Bool {
//        assert(bit >= 0 && bit < UInt.bitWidth)
//        return value & (1 &<< bit) != 0
//    }
//
//    @inlinable
//    @inline(__always)
//    mutating func insert(_ bit: Int) -> Bool {
//        assert(bit >= 0 && bit < UInt.bitWidth)
//        let mask: UInt = 1 &<< bit
//        let inserted = self.value & mask == 0
//        self.value |= mask
//        return inserted
//    }
//
//    @inlinable
//    @inline(__always)
//    mutating func remove(_ bit: Int) -> Bool {
//        assert(bit >= 0 && bit < UInt.bitWidth)
//        let mask: UInt = 1 &<< bit
//        let removed = self.value & mask != 0
//        self.value &= ~mask
//        return removed
//    }
//}
//
//extension Bitset.Word {
//    static var capacity: Int {
//        return UInt.bitWidth
//    }
//
//    static let empty = Bitset.Word(0)
//}
//
//extension Bitset.Word: Sequence, IteratorProtocol {
//
//    /// Return the index of the lowest set bit in this word,
//    /// and also destructively clear it.
//    @inlinable
//    internal mutating func next() -> Int? {
//        guard value != 0 else { return nil }
//        let bit = value.trailingZeroBitCount
//        value &= value &- 1       // Clear lowest nonzero bit.
//        return bit
//    }
//}
