//
//  WorldPlugin+Runtime.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/20/23.
//

// We should register our systems in engine, because we should initiate them in memory
// TODO: (Vlad) Add system list to editor and generate file with registred systems.
extension WorldPlugin {
    
    /// Call this method to add system to engine.
    /// When engine will initiate system from scene file, it will try to find
    /// system in registred list.
    /// Otherwise system will not be initialized.
    @MainActor public static func registerPlugin() {
        WorldPluginStorage.register(self)
    }
    
    static var swiftName: String {
        return String(reflecting: self)
    }
}

@MainActor
enum WorldPluginStorage {
    
    private static var registeredPlugins: [String: WorldPlugin.Type] = [:]
    
    /// Return registred system or try to find it by NSClassFromString (works only for objc runtime)
    static func getRegistredPlugin(for name: String) -> WorldPlugin.Type? {
        return self.registeredPlugins[name] ?? (NSClassFromString(name) as? WorldPlugin.Type)
    }
    
    static func register<T: WorldPlugin>(_ system: T.Type) {
        self.registeredPlugins[T.swiftName] = system
    }
}
