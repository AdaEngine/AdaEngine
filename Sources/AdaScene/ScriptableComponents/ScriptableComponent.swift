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

/// Contains collection of ``ScriptableObject``.
@Component
public struct ScriptableComponents {
    public var scripts: ContiguousArray<ScriptableObject> = []

    public init(scripts: ContiguousArray<ScriptableObject>) {
        self.scripts = scripts
    }
}

/// Base class describe some unit of game logic.
/// This similar as Unity MonoBehaviour object does.
/// It can be used when you need some Unity-like component with specific behaviour.
/// ScriptableObject has it's lifecycle and not depends on system execution order. It's always called on `Update` scheduler
///
/// - Note: We don't recomend use a lot of scriptable objects, instead use ECS paradigm.
///
/// ```swift
/// final class Player: ScriptableObject {
///     func update(_ deltaTime: AdaUtils.TimeInterval) {
///         // Update player position
///         if input.isKeyPressed(.w) { ... }
///     }
/// }
///
/// func setup(in app: AppWorlds) {
///     // spawn player script in app.
///     app.spawn("Player") {
///         ScriptableComponents(scripts: [Player()]),
///         Transform()
///     }
/// }
/// ```
/// You also can get any component in entity using special ``RequiredComponent`` property wrapper.
///
/// ```swift
/// final class Player: ScriptableObject {
///
///     @RequiredComponent
///     private var sprite: Sprite
///
///     func update(_ deltaTime: AdaUtils.TimeInterval) {
///         // Update sprite tint color
///         sprite.tintColor = .random()
///     }
/// }
///
/// - Note: The execution order depends on ``ScriptableComponents``.
///
open class ScriptableObject: @unchecked Sendable {

    /// Check, that object is awaked.
    internal var isAwaked: Bool = false

    /// Returns entity where ScriptableObject attached.
    public internal(set) weak var entity: Entity?

    /// Contains input manager for handling events.
    public var input: Input {
        _read {
            yield _input.wrappedValue
        }
        _modify {
            yield &_input.wrappedValue
        }
    }

    package var _input: Ref<Input>!

    /// Create a new script component.
    public required init() {}

    deinit {
        self.destroy()
    }
    
    /// Called once when component is on scene and ready to use.
    open func ready() { }

    /// Called each frame.
    open func update(_ deltaTime: AdaUtils.TimeInterval) { }

    /// Called each frame to update gui.
    /// - Note: ``UIGraphicsContext`` has different view matrix and based on UI Ortho Transform not camera view.
    open func updateGUI(_ deltaTime: AdaUtils.TimeInterval, context: UIGraphicsContext) { }

    /// Called 60 times per second for physics and other updates.
    open func physicsUpdate(_ deltaTime: AdaUtils.TimeInterval) { }
    
    /// Called each time when scene receive events.
    open func event(_ events: [any InputEvent]) { }

    /// Called once when component removed from entity
    open func destroy() { }

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
