//
//  Ref.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A reference to a component.
/// Used to mutate component values via ``Query``.
@dynamicMemberLookup
@propertyWrapper
public final class Ref<T>: @unchecked Sendable, ChangeDetectionable {
    private let pointer: UnsafeMutablePointer<T>
    private let currentTick: UnsafeMutablePointer<Tick>
    public var changeTick: ChangeDetectionTick

    /// The wrapped value of the reference.
    @inline(__always)
    public var wrappedValue: T {
        get {
            self.pointer.pointee
        }
        set {
            self.pointer.pointee = newValue
            self.currentTick.pointee = self.changeTick.currentTick
            self.setChanged()
        }
    }

    /// Create a new reference to a component.
    /// - Parameters:
    ///   - get: A closure that returns the component value.
    ///   - set: A closure that sets the component value.
    public init(
        pointer: UnsafeMutablePointer<T>,
        currentTick: UnsafeMutablePointer<Tick>,
        changeTick: ChangeDetectionTick
    ) {
        self.pointer = pointer
        self.changeTick = changeTick
        self.currentTick = currentTick
    }

    @inline(__always)
    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U {
        get {
            return self.wrappedValue[keyPath: dynamicMember]
        }
        set {
            self.wrappedValue[keyPath: dynamicMember] = newValue
        }
    }
}

@dynamicMemberLookup
@propertyWrapper
public final class Mutable<T>: @unchecked Sendable {

    /// The getter of the reference.
    public typealias Getter = @Sendable () -> T

    /// The setter of the reference.
    public typealias Setter = @Sendable (T) -> Void

    /// The wrapped value of the reference.
    @inline(__always)
    public var wrappedValue: T {
        get {
            getValue!()
        }
        set {
            setValue?(newValue)
        }
    }

    /// Initialize a new reference.
    public init() {
        self.getValue = nil
        self.setValue = nil
    }

    /// The getter of the reference.
    @inline(__always)
    var getValue: Getter?

    /// The setter of the reference.
    @inline(__always)
    let setValue: Setter?

    /// Create a new reference to a component.
    /// - Parameters:
    ///   - get: A closure that returns the component value.
    ///   - set: A closure that sets the component value.
    public init(get: @escaping Getter, set: @escaping Setter) {
        self.getValue = get
        self.setValue = set
    }

    @inline(__always)
    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U {
        get {
            return self.wrappedValue[keyPath: dynamicMember]
        }
        set {
            self.wrappedValue[keyPath: dynamicMember] = newValue
        }
    }
}

public protocol ChangeDetectionable: AnyObject {
    var changeTick: ChangeDetectionTick { get set }

    var isChanged: Bool { get }

    func setChanged()
}

public extension ChangeDetectionable {
    var isChanged: Bool {
        return self.changeTick.change == self.changeTick.lastTick
    }

    func setChanged() {
        self.changeTick.change = self.changeTick.currentTick
    }
}
