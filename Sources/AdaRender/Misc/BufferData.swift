//
//  BufferData.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

public struct BufferData<T> {
    public var elements: [T] {
        didSet {
            self.isChanged = true
        }
    }
    public var buffer: (any Buffer)?
    public var label: String?
    public var isChanged: Bool = false

    public init(label: String? = nil, elements: [T]) {
        self.label = label
        self.elements = elements
    }
}

extension BufferData: Equatable where T: Equatable {
    public static func == (lhs: BufferData<T>, rhs: BufferData<T>) -> Bool {
        lhs.elements == rhs.elements
    }
}

extension BufferData: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.elements)
    }
}

extension BufferData: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: T...) {
        self.label = nil
        self.elements = elements
    }
}

extension BufferData: RandomAccessCollection {
    public typealias Element = T
    public typealias Index = Int

    public subscript(position: Int) -> T {
        _read {
            yield elements[position]
        }
        _modify {
            yield &elements[position]
        }
    }

    public var startIndex: Int {
        elements.startIndex
    }

    public var endIndex: Int {
        elements.endIndex
    }
}

public extension BufferData {

    var isEmpty: Bool {
        self.elements.isEmpty
    }

    var count: Int {
        self.elements.count
    }

    var bufferLength: Int {
        self.buffer?.length ?? 0
    }

    mutating func write(to renderDevice: RenderDevice) {
        reserveCapacity(self.elements.count, for: renderDevice)
        guard let buffer else {
            return
        }
        buffer.setElements(&elements)
    }

    mutating func reserveCapacity(_ count: Int, for renderDevice: RenderDevice) {
        let newCapacity = MemoryLayout<T>.stride * count
        if bufferLength >= newCapacity {
            return
        }
        self.buffer = renderDevice.createBuffer(label: label, length: newCapacity, options: .storageShared)
        self.isChanged = false
    }

    mutating func append(_ element: T) {
        self.elements.append(element)
        self.isChanged = true
    }

    mutating func removeAll() {
        self.elements.removeAll()
    }
}

extension BufferData: Sequence { }

extension BufferData: Sendable where T: Sendable { }

