//
//  Component+Runtime.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

// We should register our components in engine, because we should initiate them in memory
// TODO: (Vlad) Add components list to editor and generate file with registred components.
// TODO: (Vlad) We can think about `swift_getMangledTypeName` and `swift_getTypeByMangledNameInContext`
// This can help to avoid registring components during runtime.
extension Component {
    
    /// Call this method to add component to the engine.
    /// When engine will initiate component from scene file, it will try to find
    /// component in registred list.
    /// Otherwise component will not be initialized.
    public static func registerComponent() {
        ComponentStorage.addComponent(self)
    }
}

extension Component {
    
    /// Return name with Bundle -> AdaEngine.ComponentName
    /// - Note: We use reflection, we paid a huge cost for that.
    static var swiftName: String {
        return String(reflecting: self)
    }
    
    /// Return identifier of component based on Component.Type
    @inline(__always) static var identifier: ComponentId {
        ComponentId(id: Int(bitPattern: ObjectIdentifier(self)))
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

// https://github.com/apple/swift/blob/4435a37088b20fa7eca3c48947b0532e5221629b/stdlib/public/core/Misc.swift
//@_silgen_name("swift_getTypeByMangledNameInContext")
//internal func _getTypeByMangledNameUntrusted(
//  _ name: UnsafePointer<UInt8>,
//  _ nameLength: UInt)
//  -> Any.Type?
//
//@_silgen_name("swift_getMangledTypeName")
//public func _getTypeName(_ type: Any.Type, qualified: Bool) -> (UnsafePointer<UInt8>, Int)
