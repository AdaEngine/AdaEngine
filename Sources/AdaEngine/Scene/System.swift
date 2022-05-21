//
//  System.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation

public struct SceneUpdateContext {
    public let scene: Scene
    public let deltaTime: TimeInterval
}

public protocol System {
    
    typealias UpdateContext = SceneUpdateContext
    
    init(scene: Scene)
    
    func update(context: UpdateContext)
    
    // MARK: Dependencies
    
    static var dependencies: [SystemDependency] { get }
}

public extension System {
    static var dependencies: [SystemDependency] {
        return []
    }
}

extension System {
    
    public static func registerSystem() {
        SystemStorage.register(self)
    }
    
    static var swiftName: String {
        return String(reflecting: self)
    }
}

struct SystemStorage {
    private static var registeredSystem: [String: System.Type] = [:]
    
    static func getRegistredSystem(for name: String) -> System.Type? {
        return self.registeredSystem[name] ?? (NSClassFromString(name) as? System.Type)
    }
    
    static func register<T: System>(_ system: T.Type) {
        self.registeredSystem[T.swiftName] = system
    }
}

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
