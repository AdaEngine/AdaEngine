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
/// - Note: Only works in objects that inheritance from ``ScriptableObject`` class.
///
/// RequiredComponent very useful for scenario when you need components from entity
/// and you are really sure that that components is exists.
///
/// ```swift
///
/// class PlayerMovementComponent: ScriptableObject {
///
///     // Fetch HealthComponent component from entity where PlayerMovementComponent contains
///     @RequiredComponent
///     private var healthComponent: HealthComponent
///
///     // Logic code...
/// }
///
/// app.spawn(name: "Player") {
///     HealthComponent(health: 10)
///     ScriptableComponents(scripts: [PlayerMovementComponent()])
/// }
/// ```
@propertyWrapper
public struct RequiredComponent<T: Component> {
    
    @available(*, unavailable, message: "RequiredComponents should call only inside `ScriptableObject` classes.")
    public var wrappedValue: T {
        get { fatalError() }
        set { fatalError() }
    }
    
    public init() { }
    
    // Currently private method to get parent component
    public static subscript<EnclosingSelf: ScriptableObject>(
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
