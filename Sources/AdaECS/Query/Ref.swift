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
@safe
public struct Ref<T>: @unchecked Sendable, ChangeDetectionable {
    private let pointer: UnsafeMutablePointer<T>?
    public var changeTick: ChangeDetectionTick

    /// The wrapped value of the reference.
    @inline(__always)
    public var wrappedValue: T {
        _read {
            yield unsafe self.pointer!.pointee
        }
        nonmutating _modify {
            yield unsafe &self.pointer!.pointee
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
        unsafe self.pointer = pointer
        self.changeTick = changeTick
    }

    @inline(__always)
    public subscript<U>(dynamicMember dynamicMember: WritableKeyPath<T, U>) -> U {
        _read {
            yield self.wrappedValue[keyPath: dynamicMember]
        }
        nonmutating _modify {
            yield &self.wrappedValue[keyPath: dynamicMember]
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
        return self.changeTick.change?.wrappedValue == self.changeTick.currentTick
    }

    func setChanged() {
        self.changeTick.change?.getPointer().pointee = self.changeTick.currentTick
    }
}
