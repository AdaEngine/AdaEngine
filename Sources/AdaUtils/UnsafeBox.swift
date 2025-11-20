//
//  UnsafeBox.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 20.11.2025.
//

/// Holds and manage pointer to instance.
@propertyWrapper
@unsafe
public struct UnsafeBox<T> {

    @usableFromInline
    let box: _UnsafeBox

    @inlinable
    public var wrappedValue: T {
        _read {
            yield box.pointer.assumingMemoryBound(to: T.self).pointee
        }
        _modify {
            yield &box.pointer.assumingMemoryBound(to: T.self).pointee
        }
    }

    @inlinable
    public var projectedValue: UnsafeMutablePointer<T> {
        self.box.pointer.assumingMemoryBound(to: T.self)
    }

    @inlinable
    public init(_ block: () -> T) {
        self.box = _UnsafeBox(block())
    }

    @inlinable
    public init(_ wrappedValue: consuming T) {
        self.box = _UnsafeBox(wrappedValue)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<T>) {
        self.box = _UnsafeBox(pointer)
    }

    init(_ box: _UnsafeBox) {
        self.box = box
    }

    @inlinable
    public func getPointer() -> UnsafeMutablePointer<T> {
        self.box.pointer.assumingMemoryBound(to: T.self)
    }

    @inlinable
    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U {
        _read {
            yield self.wrappedValue[keyPath: dynamicMember]
        }
        _modify {
            yield &self.wrappedValue[keyPath: dynamicMember]
        }
    }
}

extension UnsafeBox: Sendable where T: Sendable {}

extension UnsafeBox: Equatable where T: Equatable {
    public static func == (lhs: UnsafeBox<T>, rhs: UnsafeBox<T>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension UnsafeBox: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.wrappedValue)
    }
}

extension UnsafeBox: Codable where T: Codable {
    public init(from decoder: any Decoder) throws {
        let value = try T.init(from: decoder)
        self.box = _UnsafeBox(value)
    }

    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

public extension UnsafeMutablePointer {
    @inlinable
    func unsafeBox() -> UnsafeBox<Pointee> {
        UnsafeBox(self)
    }
}

@unsafe
@usableFromInline
final class _UnsafeBox: @unchecked Sendable {
    @usableFromInline
    let pointer: UnsafeMutableRawPointer

    private let automanaged: Bool
    private let deallocator: ((UnsafeMutableRawPointer) -> Void)?

    @usableFromInline
    init<T>(_ instance: consuming T) {
        pointer = .allocate(byteCount: MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment)
        pointer.initializeMemory(as: T.self, to: instance)
        deallocator = {
            $0.assumingMemoryBound(to: T.self)
                .deinitialize(count: 1)
        }
        automanaged = true
    }

    @usableFromInline
    init<T>(_ pointer: UnsafeMutablePointer<T>) {
        self.pointer = UnsafeMutableRawPointer(pointer)
        self.deallocator = nil
        self.automanaged = false
    }

    deinit {
        guard self.automanaged else {
            return
        }
        deallocator?(pointer)
        pointer.deallocate()
    }
}

@unsafe
public struct UnsafeAnyBox {
    @usableFromInline
    let box: _UnsafeBox

    @inlinable
    public init<T>(_ block: () -> T) {
        self.box = _UnsafeBox(block())
    }

    @inlinable
    public init<T>(_ wrappedValue: consuming T) {
        self.box = _UnsafeBox(wrappedValue)
    }

    @inlinable
    public init<T>(_ pointer: UnsafeMutablePointer<T>) {
        self.box = _UnsafeBox(pointer)
    }

    public func bind<T>(to type: T.Type) -> UnsafeBox<T> {
        return UnsafeBox(box)
    }
}
