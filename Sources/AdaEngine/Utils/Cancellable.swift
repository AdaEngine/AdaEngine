//
//  Cancellable.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/3/22.
//

/// A protocol indicating that an activity or action supports cancellation.
///
/// Calling cancel() frees up any allocated resources. It also stops side effects such as timers, network access, or disk I/O.
public protocol Cancellable {
    
    /// Cancel the activity.
    func cancel()
}

public extension AnyCancellable {
    
    /// Stores this type-erasing cancellable instance in the specified set.
    func store(in buffer: inout Set<AnyCancellable>) {
        buffer.insert(self)
    }
    
    /// Stores this type-erasing cancellable instance in the specified collection.
    func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == AnyCancellable {
        collection.append(self)
    }
}

/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token”
/// that makes it possible for a caller to cancel a publisher, but not to use the Subscription object to request items.
///
/// An AnyCancellable instance automatically calls cancel() when deinitialized.
///
public final class AnyCancellable: Cancellable, Hashable, Equatable {
    
    let id: UUID
    
    let cancellable: Cancellable
    
    /// Initializes the cancellable object with the given cancallable object.
    init<T: Cancellable>(_ cancellable: T) {
        self.id = UUID()
        self.cancellable = cancellable
    }
    
    deinit {
        self.cancellable.cancel()
    }
    
    public func cancel() {
        self.cancellable.cancel()
    }
    
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
}
