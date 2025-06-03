//
//  SystemDependency.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/12/23.
//

/// Defines update order relative to other systems. An object that specifies the update order between multiple systems.
///
/// If you need to specify the update order between your system and other systems in your app, you can do that using this property.
///
/// ```swift
/// @System(dependencies: [
///     .after(EnemyChasingSystem.self), // Run MovementSystem after EnemyChasingSystem
///     .before(BulletSystem.self) // Run MovementSystem before BulletSystem
/// ])
/// struct MovementSystem {
///     // ...
/// }
/// ```
public enum SystemDependency: Sendable {
    /// Run the system before the specified system.
    case before(System.Type)

    /// Run the system after the specified system.
    case after(System.Type)
}

extension SystemDependency: Equatable {
    /// Check if two system dependencies are equal.
    /// - Parameter lhs: The left system dependency.
    /// - Parameter rhs: The right system dependency.
    /// - Returns: True if the two system dependencies are equal, otherwise false.
    public static func == (lhs: SystemDependency, rhs: SystemDependency) -> Bool {
        switch lhs {
        case .before(let system):
            switch rhs {
            case .before(let rhsSystem):
                return system == rhsSystem
            case .after:
                return false
            }
        case .after(let system):
            switch rhs {
            case .before:
                return false
            case .after(let rhsSystem):
                return system == rhsSystem
            }
        }
    }
}
