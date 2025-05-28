//
//  Atomic.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/30/24.
//

import Foundation

@propertyWrapper
@dynamicMemberLookup
public final class LockProperty<Value: Sendable>: @unchecked Sendable {
    
    /// The lock-isolated value.
    public var wrappedValue: Value {
        get {
            self.lock.sync {
                self._value
            }
        }
        
        set {
            self.lock.sync {
                self._value = newValue
            }
        }
    }
    
    private var _value: Value
    private let lock = NSRecursiveLock()
    
    /// Initializes lock-isolated state around a value.
    ///
    /// - Parameter value: A value to isolate with a lock.
    public init(_ value: @autoclosure @Sendable () throws -> Value) rethrows {
        self._value = try value()
    }
    
    public subscript<Subject: Sendable>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
        self.lock.sync {
            self._value[keyPath: keyPath]
        }
    }
    
    public init(wrappedValue value: Value) {
        self._value = value
    }
}

extension NSRecursiveLock {
  @inlinable @discardableResult
  @_spi(Internal) public func sync<R>(work: () throws -> R) rethrows -> R {
    self.lock()
    defer { self.unlock() }
    return try work()
  }
}

