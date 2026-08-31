import AdaECS

/// Scheduler metadata aggregated from registered scriptable object descriptors.
@propertyWrapper
public final class ScriptableObjectAccess: SystemParameter, @unchecked Sendable {
    public var wrappedValue: ScriptableObjectAccess { self }

    public var access: SystemAccessSet {
        ScriptableObjectRegistry.combinedDeclaredAccess()
    }

    public init() {}

    public init(from world: World) {}

    public func update(from world: World) {}
}
