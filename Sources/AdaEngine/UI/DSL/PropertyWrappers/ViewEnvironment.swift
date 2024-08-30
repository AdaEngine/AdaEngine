//
//  Environment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Observation

/// A property wrapper that reads a value from a view’s environment.
@propertyWrapper
public struct Environment<Value>: PropertyStoragable, UpdatableProperty {

    let container = ViewContextStorage()
    var storage: UpdatablePropertyStorage {
        return self.container
    }

    var readValue: (ViewContextStorage) -> Value

    public var wrappedValue: Value {
        return readValue(container)
    }
    
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.readValue = {
            $0.values[keyPath: keyPath]
        }
    }

    public func update() { }
}

extension Environment where Value: Observable & AnyObject {
    public init(_ observable: Value.Type) where Value: Observable & AnyObject {
        self.readValue = { container in
            let value = container.values.observableStorage.getValue(observable)

            return withObservationTracking {
                value
            } onChange: {
                Task { @MainActor in
                    container.update()
                }
            }
        }
    }
}

final class ViewContextStorage: UpdatablePropertyStorage {
    var values: EnvironmentValues = EnvironmentValues()
}

/// A key for accessing values in the environment.
///
/// You can create custom environment values by extending the ``EnvironmentValues`` structure with new properties.
/// First declare a new environment key type and specify a value for the required defaultValue property:
///
/// ```swift
/// private struct MyEnvironmentKey: EnvironmentKey {
///     static let defaultValue: String = "Default value"
/// }
/// ```
/// 
/// Then use the key to define a new environment value property:
/// ```swift
/// extension EnvironmentValues {
///     var myCustomValue: String {
///         get { self[MyEnvironmentKey.self] }
///         set { self[MyEnvironmentKey.self] = newValue }
///     }
/// }
/// ```
///
/// Clients of your environment value never use the key directly. Instead, they use the key path of your
/// custom environment value property. To set the environment value for a view and all its subviews, 
/// add the ``View/environment(_:_:)`` view modifier to that view:
///
/// ```swift
/// MyView()
///    .environment(\.myCustomValue, "Another string")
/// ```
///
/// To read the value from inside MyView or one of its descendants, use the ``Environment`` property wrapper:
///
/// ```swift
/// struct MyView: View {
///     @Environment(\.myCustomValue) var customValue: String
///
///     var body: some View {
///         Text(customValue) // Displays "Another string".
///     }
/// }
/// ```
public protocol EnvironmentKey {
    associatedtype Value

    static var defaultValue: Value { get }
}

/// A collection of environment values propagated through a view hierarchy.
///
/// AdaEngine exposes a collection of values to your app’s views in an EnvironmentValues structure. 
/// To read a value from the structure, declare a property using the ``Environment`` property wrapper
/// and specify the value’s key path.
/// For example, you can read the current scale factor:
///
/// ```swift
/// @ViewEnvironment(\.scaleFactor) private var scaleFactor
/// ```
///
/// You can set or override some values using the ``View/environment(_:_:)`` view modifier:
///
/// ```swift
/// MyView()
///     .environment(\.scaleFactor, 2)
/// ```
///
/// Create a custom environment value by declaring a new property in an extension to the environment values structure and applying the ``Entry()`` macro to the variable declaration:
///
/// ```swift
/// extension EnvironmentValues {
///     @Entry var myCustomValue: String = "Default value"
/// }
/// ```
///
/// Also recommended using extensions for view to modify your environment value:
///
/// ```swift
/// extension View {
///     func myCustomValue(_ myCustomValue: String) -> some View {
///         environment(\.myCustomValue, myCustomValue)
///     }
/// }
/// ```
public struct EnvironmentValues {
    
    private var values: [ObjectIdentifier: Any] = [:]
    
    /// Creates an environment values instance.
    public init() { }

    /// Accesses the environment value associated with a custom key.
    public subscript<K: EnvironmentKey>(_ type: K.Type) -> K.Value {
        get {
            (self.values[ObjectIdentifier(type)] as? K.Value) ?? K.defaultValue
        }
        set {
            self.values[ObjectIdentifier(type)] = newValue
        }
    }

    mutating func merge(_ newValue: EnvironmentValues) {
        self.values.merge(newValue.values, uniquingKeysWith: { $1 })
    }
}
