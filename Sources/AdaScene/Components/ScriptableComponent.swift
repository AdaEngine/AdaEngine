//
//  ScriptableComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/24/22.
//

import AdaECS
import AdaUtils
import AdaUI
import AdaTransform
import AdaInput

public struct ScriptableComponent<T: ScriptableObject>: Component {
    public let object: ScriptableObject

    public init(object: ScriptableObject) {
        self.object = object
    }
}

/// Base class describe some unit of game logic.
///
/// - Note: We don't recomend use a lot of scriptable objects, instead use ECS paradigm.
///
/// It can be used when you need some Unity-like component with specific behaviour.
///
/// - Warning: AdaEngine doesn't has execution order for `ScriptableComponent`.
///
open class ScriptableObject: @unchecked Sendable {

    internal var isAwaked: Bool = false
    
    public internal(set) weak var entity: Entity?
    
    /// Create a new script component.
    public required init() {}

    deinit {
        self.onDestroy()
    }
    
    /// Called once when component is on scene and ready to use.
    open func onReady() { }

    /// Called each frame.
    open func onUpdate(_ deltaTime: AdaUtils.TimeInterval) { }
    
    /// Called each frame to update gui.
    @MainActor
    open func onUpdateGUI(_ deltaTime: AdaUtils.TimeInterval, context: UIGraphicsContext) {

    }
    
    /// Called each time with interval in seconds for physics and other updates.
    open func onPhysicsUpdate(_ deltaTime: AdaUtils.TimeInterval) {

    }
    
    /// Called each time when scene receive events.
    open func onEvent(_ events: [any InputEvent]) {

    }
    
    /// Called once when component removed from entity
    open func onDestroy() {
        
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
                
                // propertyName here is not necessarily used in the `encodeValue` method
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

public extension ScriptableObject {
    /// Get collection of components in entity
    /// - Warning: Crashed if component not connected to entity.
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
    func insertComponent<T: Component>(_ component: T) {
        self.entity?.components.insert(component)
    }
}

public extension ScriptableObject {
    /// Return transform component for current entity.
    var transform: Transform {
        get {
            return self.components[Transform.self]!
        }

        set {
            return self.components[Transform.self] = newValue
        }
    }

    /// Return global transform component for current entity.
    var globalTransform: GlobalTransform {
        return self.components[GlobalTransform.self]!
    }
}
