//
//  MeshArray.swift
//  
//
//  Created by v.prusakov on 11/9/21.
//


public struct MeshArray<Element>: Sequence {
    
    public typealias Element = Element
    
    public typealias Iterator = ChunkIterator<Element>
    
    private var buffer: _Buffer
    
    // MARK: - Public Methods
    
    public func makeIterator() -> Iterator {
        return Iterator(buffer: self.buffer)
    }
    
    public var elements: [Element] {
        return self.buffer.getData()
    }
    
    public var count: Int {
        return self.buffer.count
    }
    
    public func forEach(_ body: (Element, Element) throws -> Void) rethrows {
        let iterator = ChunkIterator<(Element, Element)>(buffer: self.buffer)
        
        while let element = iterator.next() {
            try body(element.0, element.1)
        }
    }
    
    public func forEach(_ body: (Element, Element, Element) throws -> Void) rethrows {
        let iterator = ChunkIterator<(Element, Element, Element)>(buffer: self.buffer)
        
        while let element = iterator.next() {
            try body(element.0, element.1, element.2)
        }
    }
    
    public func forEach(_ body: (Element, Element, Element, Element) throws -> Void) rethrows {
        let iterator = ChunkIterator<(Element, Element, Element, Element)>(buffer: self.buffer)
        
        while let element = iterator.next() {
            try body(element.0, element.1, element.2, element.3)
        }
    }
    
    // MARK: - Internal Methods
    
    var indecies: [UInt32] {
        return self.buffer.getIndecies()
    }
}

extension MeshArray {
    
    public struct ChunkIterator<T>: IteratorProtocol {
        private let buffer: _Buffer
        private let currentChunk: UnsafeMutablePointer<Int>
        
        internal init(buffer: _Buffer) {
            self.buffer = buffer
            self.currentChunk = UnsafeMutablePointer<Int>.allocate(capacity: MemoryLayout<Int>.size)
            self.currentChunk.pointee = 0
        }
        
        public func next() -> T? {
            let nextElement = self.buffer.getChunk(withOffset: currentChunk.pointee, type: T.self)
            currentChunk.pointee += MemoryLayout<T>.stride
            if nextElement == nil {
                currentChunk.deinitialize(count: 1)
                currentChunk.deallocate()
                return nil
            }
            
            return nextElement
        }
    }
    
    class _Buffer: Equatable {
        
        private let bufferPointer: UnsafeMutableRawBufferPointer
        private var indiciesPointer: UnsafeMutableBufferPointer<UInt32>
        
        init(elements: [Element], indecies: [UInt32]) {
            self.bufferPointer = UnsafeMutableRawBufferPointer.allocate(
                byteCount: MemoryLayout<Element>.stride * elements.count,
                alignment: 0 // TODO: needs tests
            )
            
            self.bufferPointer.baseAddress?.copyMemory(
                from: elements,
                byteCount: MemoryLayout<Element>.stride * elements.count
            )
            
            self.indiciesPointer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: indecies.count)
            
            _ = self.indiciesPointer.initialize(from: indecies)
        }
        
        deinit {
            self.bufferPointer.deallocate()
            self.indiciesPointer.deallocate()
        }
        
        static func == (lhs: MeshArray<Element>._Buffer, rhs: MeshArray<Element>._Buffer) -> Bool {
            return lhs.bufferPointer.baseAddress == rhs.bufferPointer.baseAddress &&
            lhs.indiciesPointer.baseAddress == rhs.indiciesPointer.baseAddress
        }
        
        // MARK: - Internal
        
        var count: Int {
            return self.bufferPointer.count / MemoryLayout<Element>.stride
        }
        
        func getChunk<T>(withOffset offset: Int, type: T.Type) -> T? {
            guard offset < self.bufferPointer.endIndex else {
                return nil
            }
            return self.bufferPointer.load(fromByteOffset: offset, as: T.self)
        }
        
        func getIndecies() -> [UInt32] {
            Array(self.indiciesPointer)
        }
        
        func getData() -> [Element] {
            Array(self.bufferPointer.bindMemory(to: Element.self))
        }
    }
}

public extension MeshArray where Element == Int8 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == UInt8 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Int16 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == UInt16 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Int32 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == UInt32 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Float {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Double {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Vector2 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Vector3 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}

public extension MeshArray where Element == Vector4 {
    
    init(_ array: [Element]) {
        self.buffer = _Buffer(elements: array, indecies: [])
    }
    
    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _Buffer(elements: elements, indecies: indecies)
    }
    
    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _Buffer(elements: Array(sequence), indecies: [])
    }
}
