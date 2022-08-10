////
////  MeshArray.swift
////
////
////  Created by v.prusakov on 11/9/21.
////
//
//public struct MeshArray<Element>: Sequence {
//
//    public typealias Element = Element
//
//    public typealias Iterator = ChunkIterator<Element>
//
//    internal var buffer: _MeshArrayBuffer
//
//    // MARK: - Public Methods
//
//    public func makeIterator() -> Iterator {
//        return Iterator(buffer: self.buffer)
//    }
//
//    public var elements: [Element] {
//        return self.buffer.getData()
//    }
//
//    public var count: Int {
//        return self.buffer.count
//    }
//
//    public func forEach(_ body: (Element, Element) throws -> Void) rethrows {
//        let iterator = ChunkIterator<(Element, Element)>(buffer: self.buffer)
//
//        while let element = iterator.next() {
//            try body(element.0, element.1)
//        }
//    }
//
//    public func forEach(_ body: (Element, Element, Element) throws -> Void) rethrows {
//        let iterator = ChunkIterator<(Element, Element, Element)>(buffer: self.buffer)
//
//        while let element = iterator.next() {
//            try body(element.0, element.1, element.2)
//        }
//    }
//
//    public func forEach(_ body: (Element, Element, Element, Element) throws -> Void) rethrows {
//        let iterator = ChunkIterator<(Element, Element, Element, Element)>(buffer: self.buffer)
//
//        while let element = iterator.next() {
//            try body(element.0, element.1, element.2, element.3)
//        }
//    }
//
//    // MARK: - Internal Methods
//
//    var indices: [UInt32] {
//        return self.buffer.getIndices()
//    }
//
//    init(buffer: _MeshArrayBuffer) {
//        self.buffer = buffer
//    }
//}
//
//extension MeshArray {
//
//    public struct ChunkIterator<T>: IteratorProtocol {
//        private let buffer: _MeshArrayBuffer
//        private let currentChunk: UnsafeMutablePointer<Int>
//
//        internal init(buffer: _MeshArrayBuffer) {
//            self.buffer = buffer
//            self.currentChunk = UnsafeMutablePointer<Int>.allocate(capacity: MemoryLayout<Int>.size)
//            self.currentChunk.pointee = 0
//        }
//
//        public func next() -> T? {
//            let nextElement = self.buffer.getChunk(withOffset: currentChunk.pointee, type: T.self)
//            currentChunk.pointee += MemoryLayout<T>.stride
//
//            if nextElement == nil {
//                currentChunk.deinitialize(count: 1)
//                currentChunk.deallocate()
//                return nil
//            }
//
//            return nextElement
//        }
//    }
//}
//
//class _MeshArrayBuffer: Equatable {
//
//    private let bufferPointer: UnsafeMutableRawBufferPointer
//    private let indicesPointer: UnsafeMutableBufferPointer<UInt32>
//    private let elementStride: Int
//    internal let elementType: Mesh.ElementType
//
//    init<Element>(elements: [Element], indices: [UInt32], elementType: Mesh.ElementType) {
//        self.elementStride = MemoryLayout<Element>.stride
//        self.elementType = elementType
//
//        self.bufferPointer = UnsafeMutableRawBufferPointer.allocate(
//            byteCount: self.elementStride * elements.count,
//            alignment: 0 // TODO: (Vlad) needs tests
//        )
//
//        self.bufferPointer.baseAddress?.copyMemory(
//            from: elements,
//            byteCount: self.elementStride * elements.count
//        )
//
//        self.indicesPointer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: indices.count)
//
//        _ = self.indicesPointer.initialize(from: indices)
//    }
//
//    deinit {
//        self.bufferPointer.deallocate()
//        self.indicesPointer.deallocate()
//    }
//
//    // MARK: - Internal
//
//    static func == (lhs: _MeshArrayBuffer, rhs: _MeshArrayBuffer) -> Bool {
//        return lhs.bufferPointer.baseAddress == rhs.bufferPointer.baseAddress &&
//        lhs.indicesPointer.baseAddress == rhs.indicesPointer.baseAddress &&
//        lhs.elementStride == rhs.elementStride
//    }
//
//    var count: Int {
//        return self.bufferPointer.count / self.elementStride
//    }
//
//    func getChunk<T>(withOffset offset: Int, type: T.Type) -> T? {
//        guard offset < self.bufferPointer.endIndex else {
//            return nil
//        }
//        return self.bufferPointer.load(fromByteOffset: offset, as: T.self)
//    }
//
//    func getIndices() -> [UInt32] {
//        Array(self.indicesPointer)
//    }
//
//    func getData<Element>() -> [Element] {
//        Array(self.bufferPointer.bindMemory(to: Element.self))
//    }
//}
//
//extension MeshArray: Equatable { }
//
//public extension MeshArray where Element == Int8 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .int8)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .int8)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .int8)
//    }
//}
//
//public extension MeshArray where Element == UInt8 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .uint8)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .uint8)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .uint8)
//    }
//}
//
//public extension MeshArray where Element == Int16 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .int16)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .int16)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .int16)
//    }
//}
//
//public extension MeshArray where Element == UInt16 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .uint16)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .uint16)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .uint16)
//    }
//}
//
//public extension MeshArray where Element == Int32 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .int32)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .int32)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .int32)
//    }
//}
//
//public extension MeshArray where Element == UInt32 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .uint32)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .uint32)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .uint32)
//    }
//}
//
//public extension MeshArray where Element == Float {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .float)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .float)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .float)
//    }
//}
//
//public extension MeshArray where Element == Double {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .double)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .double)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .double)
//    }
//}
//
//public extension MeshArray where Element == Vector2 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .vector2)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .vector2)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .vector2)
//    }
//}
//
//public extension MeshArray where Element == Vector3 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .vector3)
//    }
//
//    init(elements: [Element], indecies: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indecies, elementType: .vector3)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .vector3)
//    }
//}
//
//public extension MeshArray where Element == Vector4 {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .vector4)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .vector4)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .vector4)
//    }
//}
//
//public extension MeshArray where Element == Color {
//
//    init(_ array: [Element]) {
//        self.buffer = _MeshArrayBuffer(elements: array, indices: [], elementType: .vector4)
//    }
//
//    init(elements: [Element], indices: [UInt32]) {
//        self.buffer = _MeshArrayBuffer(elements: elements, indices: indices, elementType: .vector4)
//    }
//
//    init<S>(_ sequence: S) where S : Sequence, S.Element == Element {
//        self.buffer = _MeshArrayBuffer(elements: Array(sequence), indices: [], elementType: .vector4)
//    }
//}
//
//public struct AnyMeshArray {
//
//    typealias Buffer = _MeshArrayBuffer
//
//    private let buffer: Buffer
//
//    init(_ buffer: Buffer) {
//        self.buffer = buffer
//    }
//
//    init<V>(_ meshArray: MeshArray<V>) {
//        self.buffer = meshArray.buffer
//    }
//
//    public var count: Int {
//        self.buffer.count
//    }
//
//    public var elementType: Mesh.ElementType {
//        return self.buffer.elementType
//    }
//
//    public func get<Value>(as type: Value.Type) -> MeshArray<Value>? {
//        let buffer = self.buffer
//        return MeshArray<Value>(buffer: buffer)
//    }
//}
