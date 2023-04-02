//
//  MeshArray.swift
//
//
//  Created by v.prusakov on 11/9/21.
//

public struct MeshBuffer<Element>: Sequence {

    public typealias Element = Element

    public typealias Iterator = ChunkIterator<Element>

    internal var buffer: _MeshBuffer

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

    var indices: [UInt32] {
        return self.buffer.getIndices()
    }

    init(buffer: _MeshBuffer) {
        self.buffer = buffer
    }
}

extension MeshBuffer {

    public struct ChunkIterator<T>: IteratorProtocol {
        private let buffer: _MeshBuffer
        private let currentChunk: UnsafeMutablePointer<Int>

        internal init(buffer: _MeshBuffer) {
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
}

extension MeshBuffer: ExpressibleByArrayLiteral {
    // swiftlint:disable:next cyclomatic_complexity
    public init(arrayLiteral elements: Element...) {
        
        let type: Mesh.ElementType
        
        if let valueType = elements.first {
            switch valueType {
            case is Int8:
                type = .int8
            case is UInt8:
                type = .uint8
            case is Int16:
                type = .int16
            case is UInt16:
                type = .uint16
            case is Int32:
                type = .int32
            case is UInt32:
                type = .uint32
            case is Float:
                type = .float
            case is Vector2:
                type = .vector2
            case is Vector3:
                type = .vector3
            case is Vector4:
                type = .vector4
            default:
                fatalError("[MeshBuffer] Type not supported.")
            }
        } else {
            fatalError("[MeshBuffer] Unrelated type.")
        }
        
        self.init(buffer: _MeshBuffer(elements: elements, indices: [], elementType: type))
    }
}

class _MeshBuffer: Equatable {

    internal let bytes: UnsafeMutableRawBufferPointer
    private let indicesPointer: UnsafeMutableBufferPointer<UInt32>
    internal let elementSize: Int
    internal let elementType: Mesh.ElementType

    init<Element>(elements: [Element], indices: [UInt32], elementType: Mesh.ElementType) {
        self.elementSize = MemoryLayout<Element>.size
        self.elementType = elementType

        self.bytes = UnsafeMutableRawBufferPointer.allocate(
            byteCount: self.elementSize * elements.count,
            alignment: MemoryLayout<Element>.alignment
        )

        self.bytes.baseAddress?.copyMemory(
            from: elements,
            byteCount: self.elementSize * elements.count
        )

        self.indicesPointer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: indices.count)

        _ = self.indicesPointer.initialize(from: indices)
    }

    deinit {
        self.bytes.deallocate()
        self.indicesPointer.deallocate()
    }

    // MARK: - Internal

    static func == (lhs: _MeshBuffer, rhs: _MeshBuffer) -> Bool {
        lhs.bytes.elementsEqual(rhs.bytes) &&
        lhs.indicesPointer.elementsEqual(rhs.indicesPointer) &&
        lhs.elementSize == rhs.elementSize
    }

    var count: Int {
        return self.bytes.count / self.elementSize
    }
    
    func iterateByElements(_ block: (Int, UnsafeMutableRawPointer) -> Void) {
        var currentIndex = 0
        let count = self.count
        
        while currentIndex < count {
            let pointer = self.bytes.baseAddress!.advanced(by: currentIndex * self.elementSize)
            
            block(currentIndex, pointer)
            
            currentIndex += 1
        }
    }

    func getChunk<T>(withOffset offset: Int, type: T.Type) -> T? {
        guard offset < self.bytes.endIndex else {
            return nil
        }
        return self.bytes.load(fromByteOffset: offset, as: T.self)
    }

    func getIndices() -> [UInt32] {
        Array(self.indicesPointer)
    }

    func getData<Element>() -> [Element] {
        Array(self.bytes.bindMemory(to: Element.self))
    }
}

extension MeshBuffer: Equatable { }

public extension MeshBuffer where Element == Int8 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .int8)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .int8)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .int8)
    }
}

public extension MeshBuffer where Element == UInt8 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .uint8)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .uint8)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .uint8)
    }
}

public extension MeshBuffer where Element == Int16 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .int16)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .int16)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .int16)
    }
}

public extension MeshBuffer where Element == UInt16 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .uint16)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .uint16)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .uint16)
    }
}

public extension MeshBuffer where Element == Int32 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .int32)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .int32)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .int32)
    }
}

public extension MeshBuffer where Element == UInt32 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .uint32)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .uint32)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .uint32)
    }
}

public extension MeshBuffer where Element == Float {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .float)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .float)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .float)
    }
}

public extension MeshBuffer where Element == Vector2 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .vector2)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .vector2)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .vector2)
    }
}

public extension MeshBuffer where Element == Vector3 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .vector3)
    }

    init(elements: [Element], indecies: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indecies, elementType: .vector3)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .vector3)
    }
}

public extension MeshBuffer where Element == Vector4 {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .vector4)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .vector4)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .vector4)
    }
}

public extension MeshBuffer where Element == Color {

    init(_ array: [Element]) {
        self.buffer = _MeshBuffer(elements: array, indices: [], elementType: .vector4)
    }

    init(elements: [Element], indices: [UInt32]) {
        self.buffer = _MeshBuffer(elements: elements, indices: indices, elementType: .vector4)
    }

    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
        self.buffer = _MeshBuffer(elements: Array(sequence), indices: [], elementType: .vector4)
    }
}

public struct AnyMeshBuffer {

    typealias Buffer = _MeshBuffer

    internal let buffer: Buffer

    init(_ buffer: Buffer) {
        self.buffer = buffer
    }

    init<V>(_ meshArray: MeshBuffer<V>) {
        self.buffer = meshArray.buffer
    }

    public var count: Int {
        self.buffer.count
    }

    public var elementType: Mesh.ElementType {
        return self.buffer.elementType
    }

    public func get<Value>(as type: Value.Type) -> MeshBuffer<Value>? {
        let buffer = self.buffer
        return MeshBuffer<Value>(buffer: buffer)
    }
}
