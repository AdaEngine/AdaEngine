//
//  System.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

public struct SceneUpdateContext {
    public let scene: Scene
    public let deltaTime: TimeInterval
}

public enum SystemDependency {
    case before(System.Type)
    case after(System.Type)
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
