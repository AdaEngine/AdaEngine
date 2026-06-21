//
//  SystemAccessSet.swift
//  AdaEngine
//

/// Describes the world data a system may read or write.
///
/// Two access sets are compatible when neither writes data the other reads or writes.
/// This mirrors the scheduling rule used by ECS executor.
public struct SystemAccessSet: Sendable, Equatable {
    private var componentReads: Set<ComponentId> = []
    private var componentWrites: Set<ComponentId> = []
    private var resourceReads: Set<ObjectIdentifier> = []
    private var resourceWrites: Set<ObjectIdentifier> = []

    /// True when the system records structural world mutations that must be
    /// applied after the system has finished running.
    public private(set) var hasDeferredWorldAccess: Bool = false

    /// Creates an empty access set.
    public init() {}

    /// Adds shared component access.
    public mutating func addComponentRead<T: Component>(_ component: T.Type) {
        componentReads.insert(T.identifier)
    }

    /// Adds exclusive component access.
    public mutating func addComponentWrite<T: Component>(_ component: T.Type) {
        componentReads.insert(T.identifier)
        componentWrites.insert(T.identifier)
    }

    /// Adds shared resource access.
    public mutating func addResourceRead<T: Resource>(_ resource: T.Type) {
        resourceReads.insert(T.resourceIdentifier)
    }

    /// Adds exclusive resource access.
    public mutating func addResourceWrite<T: Resource>(_ resource: T.Type) {
        resourceReads.insert(T.resourceIdentifier)
        resourceWrites.insert(T.resourceIdentifier)
    }

    /// Marks this access as producing deferred world commands.
    public mutating func addDeferredWorldAccess() {
        hasDeferredWorldAccess = true
    }

    /// Merges another access set into this one.
    public mutating func formUnion(_ other: SystemAccessSet) {
        componentReads.formUnion(other.componentReads)
        componentWrites.formUnion(other.componentWrites)
        resourceReads.formUnion(other.resourceReads)
        resourceWrites.formUnion(other.resourceWrites)
        hasDeferredWorldAccess = hasDeferredWorldAccess || other.hasDeferredWorldAccess
    }

    /// Returns a new access set containing accesses from both inputs.
    public func union(_ other: SystemAccessSet) -> SystemAccessSet {
        var result = self
        result.formUnion(other)
        return result
    }

    /// Returns true when both access sets can run at the same time.
    public func isCompatible(with other: SystemAccessSet) -> Bool {
        if !componentWrites.isDisjoint(with: other.componentReads) {
            return false
        }
        if !other.componentWrites.isDisjoint(with: componentReads) {
            return false
        }
        if !resourceWrites.isDisjoint(with: other.resourceReads) {
            return false
        }
        if !other.resourceWrites.isDisjoint(with: resourceReads) {
            return false
        }
        return true
    }
}
