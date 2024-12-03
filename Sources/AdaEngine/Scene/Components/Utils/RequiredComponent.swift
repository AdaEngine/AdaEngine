//
//  RequiredComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

// swiftlint:disable unused_setter_value

/// Get required component from entity. 
/// If components not exists returns fatal error.
///
/// - Note: Only works in objects that inheritance from ``ScriptableComponent`` class.
///
/// RequiredComponent very useful for scenario when you need components from entity
/// and you are really sure that that components is exists.
///
/// ```swift
///
/// class PlayerMovementComponent: ScriptableComponent {
///
///     // Fetch HealthComponent component from entity where PlayerMovementComponent contains
///     @RequiredComponent private var healthComponent: HealthComponent
///
///     // Logic code...
/// }
///
/// let entity = Entity(name: "Player")
/// entity.components += PlayerMovementComponent()
/// entity.components += HealthComponent(health: 10)
/// ```
@propertyWrapper
public struct RequiredComponent<T: Component> {
    
    @available(*, unavailable, message: "RequiredComponents should call only inside `Component` classes.")
    public var wrappedValue: T {
        get { fatalError() }
        set { fatalError() }
    }
    
    public init() { }
    
    // Currently private method to get parent component 
    @MainActor
    public static subscript<EnclosingSelf: ScriptableComponent>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: KeyPath<EnclosingSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, RequiredComponent>
    ) -> T {
        get {
            return object.components[T.self]!
        }
        
        set {
            object.components[T.self] = newValue
        }
    }
    
}

// swiftlint:enable unused_setter_value
