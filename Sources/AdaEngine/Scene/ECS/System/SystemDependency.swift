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
///
/// struct MovementSystem: System {
///     static var dependencies: [SystemDependency] = [
///         .after(EnemyChasingSystem.self) // Run MovementSystem after EnemyChasingSystem
///         .before(BulletSystem.self) // Run MovementSystem before BulletSystem
///     ]
///
///     // ...
/// }
///
/// ```
public enum SystemDependency {
    case before(System.Type)
    case after(System.Type)
}

extension SystemDependency: Equatable {
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
