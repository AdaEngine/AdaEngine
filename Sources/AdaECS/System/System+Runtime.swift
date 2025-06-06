//
//  System+Runtime.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

import Foundation

// We should register our systems in engine, because we should initiate them in memory
// TODO: (Vlad) Add system list to editor and generate file with registred systems.
extension System {
    
    /// Call this method to add system to engine.
    /// When engine will initiate system from scene file, it will try to find
    /// system in registred list.
    /// Otherwise system will not be initialized.
    @MainActor
    public static func registerSystem() {
        SystemStorage.register(self)
    }
    
    /// The Swift name of the system.
    static var swiftName: String {
        return String(reflecting: self)
    }
}

enum SystemStorage {
    
    nonisolated(unsafe) private static var registeredSystem: [String: System.Type] = [:]
    
    /// Return registred system or try to find it by NSClassFromString (works only for objc runtime)
    static func getRegistredSystem(for name: String) -> System.Type? {
        return self.registeredSystem[name] ?? (NSClassFromString(name) as? System.Type)
    }

    static func register<T: System>(_ system: T.Type) {
        self.registeredSystem[T.swiftName] = system
    }
}
