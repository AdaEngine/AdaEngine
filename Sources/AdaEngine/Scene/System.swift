//
//  System.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation

public struct SystemUpdateContext {
    let scene: Scene
    let deltaTime: TimeInterval
}

public protocol System {
    typealias UpdateContext = SystemUpdateContext
    func update(context: UpdateContext)
    
    init(scene: Scene)
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
