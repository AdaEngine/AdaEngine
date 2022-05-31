//
//  Component+Runtime.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

// We should register our components in engine, because we should initiate them in memory
// TODO: Add components list to editor and generate file with registred components.
extension Component {
    
    /// Call this method to add component to the engine.
    /// When engine will initiate component from scene file, it will try to find
    /// component in registred list.
    /// Otherwise component will not be initialized.
    public static func registerComponent() {
        ComponentStorage.addComponent(self)
    }
    
    /// Return name with Bundle -> AdaEngine.ComponentName
    static var swiftName: String {
        return String(reflecting: self)
    }
}

enum ComponentStorage {
    
    private static var registedComponents: [String: Component.Type] = [:]
    
    /// Return registred component or try to find it by NSClassFromString (works only for objc runtime)
    static func getRegistredComponent(for name: String) -> Component.Type? {
        return self.registedComponents[name] ?? (NSClassFromString(name) as? Component.Type)
    }
    
    static func addComponent<T: Component>(_ type: T.Type) {
        self.registedComponents[T.swiftName] = type
    }

}
