//
//  Ref.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

import AdaUtils

/// A reference to a component.
/// Used to mutate component values via ``Query``.
@dynamicMemberLookup
@propertyWrapper
public final class Ref<T>: @unchecked Sendable, ChangeDetectionable {
    private let pointer: UnsafeMutablePointer<T>?
    public var changeTick: ChangeDetectionTick

    /// The wrapped value of the reference.
    @inline(__always)
    public var wrappedValue: T {
        get {
            self.pointer!.pointee
        }
        set {
            self.pointer!.pointee = newValue
            self.setChanged()
        }
    }

    /// Create a new reference to a component.
    /// - Parameters:
    ///   - get: A closure that returns the component value.
    ///   - set: A closure that sets the component value.
    public init(
        pointer: UnsafeMutablePointer<T>?,
        changeTick: ChangeDetectionTick
    ) {
        self.pointer = pointer
        self.changeTick = changeTick
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

public protocol ChangeDetectionable {
    var changeTick: ChangeDetectionTick { get set }

    var isChanged: Bool { get }

    func setChanged()
}

public extension ChangeDetectionable {
    var isChanged: Bool {
        return self.changeTick.change?.wrappedValue == self.changeTick.lastTick
    }

    func setChanged() {
        self.changeTick.change?.getPointer().pointee = self.changeTick.currentTick
    }
}
