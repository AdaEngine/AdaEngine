//
//  Component.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public protocol Component: Codable {
    
}

/// Base class describe some unit of game logic
open class ScriptComponent: Component {
    
    internal var isAwaked: Bool = false
    
    public internal(set) weak var entity: Entity?
    
    public required init() {}
    
    /// Called once when component is ready to use
    open func ready() {
        
    }
    
    /// Called each frame
    open func update(_ deltaTime: TimeInterval) {
        
    }
    
    /// Called each time with interval in seconds for physics and other updates.
    open func physicsUpdate(_ deltaTime: TimeInterval) {
        
    }
    
    /// Called once when component removed from entity
    open func destroy() {
        
    }
    
    // MARK: - Codable
    
    public required init(from decoder: Decoder) throws {
        var mirror: Mirror? = Mirror(reflecting: self)
        
        let container = try decoder.container(keyedBy: CodingName.self)
        
        // Go through all mirrors (till top most superclass)
        repeat {
            // If mirror is nil (no superclassMirror was nil), break
            guard let children = mirror?.children else { break }
            
            // Try to decode each child
            for child in children {
                guard let decodableKey = child.value as? _ExportDecodable else { continue }
                
                // Get the propertyName of the property. By syntax, the property name is
                // in the form: "_name". Dropping the "_" -> "name"
                let propertyName = String((child.label ?? "").dropFirst())
                
                try decodableKey.decode(
                    from: container,
                    propertyName: propertyName,
                    userInfo: decoder.userInfo
                )
            }
            mirror = mirror?.superclassMirror
        } while mirror != nil
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingName.self)
        
        var mirror: Mirror? = Mirror(reflecting: self)
        
        // Go through all mirrors (till top most superclass)
        repeat {
            // If mirror is nil (no superclassMirror was nil), break
            guard let children = mirror?.children else { break }
            
            // Try to encode each child
            for child in children {
                guard let encodableKey = child.value as? _ExportEncodable else { continue }
                
                // Get the propertyName of the property. By syntax, the property name is
                // in the form: "_name". Dropping the "_" -> "name"
                let propertyName = String((child.label ?? "").dropFirst())
                
                // propertyName here is not neceserly used in the `encodeValue` method
                try encodableKey.encode(
                    to: &container,
                    propertyName: propertyName,
                    userInfo: encoder.userInfo
                )
            }
            mirror = mirror?.superclassMirror
        } while mirror != nil
    }
    
}

public extension ScriptComponent {
    
    /// Get collection of components in entity
    /// - Warning: Crashed if component not connected to any entity.
    var components: Entity.ComponentSet {
        get {
            guard let entity = self.entity else {
                fatalError("Component not connected to any entity")
            }
            
            return entity.components
        }
        
        set {
            self.entity?.components = newValue
        }
        
    }
    
    
    /// Set component to entity
    func setComponent<T: Component>(_ component: T) {
        self.entity?.components.set(component)
    }
}

import Foundation

extension Component {
    static func registerComponent() {
        let token = String(reflecting: Self.self)
        ComponentStorage.registedComponents[token] = Self.self
    }
    
    
    static var swiftName: String {
        return String(reflecting: Self.self)
    }
}

struct ComponentStorage {
    
    static func getRegistredComponent(for name: String) -> Component.Type? {
        return self.registedComponents[name] ?? (NSClassFromString(name) as? Component.Type)
    }
    
    static var registedComponents: [String: Component.Type] = [:]

}
