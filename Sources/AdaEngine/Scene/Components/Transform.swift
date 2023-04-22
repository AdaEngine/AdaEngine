//
//  Transform.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

/// Component contains information about entity transform. This is main component for entities which want be rendering.
public struct Transform: Component {
    
    /// Contains rotation of model.
    public var rotation: Quat
    
    /// Contains scale of model.
    public var scale: Vector3
    
    /// Contains position of model.
    public var position: Vector3
    
    /// Create a new transform component from rotation, scale and position.
    public init(
        rotation: Quat = .identity,
        scale: Vector3 = [1, 1, 1],
        position: Vector3 = .zero
    ) {
        self.rotation = rotation
        self.scale = scale
        self.position = position
    }
    
    /// Create a new transform component from transformation matrix.
    public init(matrix: Transform3D) {
        self.rotation = matrix.rotation
        self.scale = matrix.scale
        self.position = matrix.origin
    }
}

public extension Transform {
    
    /// Return transformation matrix for transform component.
    /// - Note: Getter of this property is compute. 
    var matrix: Transform3D {
        get {
            Transform3D(
                translation: self.position,
                rotation: self.rotation,
                scale: self.scale
            )
        }
        
        set {
            self.scale = newValue.scale
            self.rotation = newValue.rotation
            self.position = newValue.origin
        }
    }
}

public extension ScriptComponent {
    
    /// Return transform component for current entity.
    var transform: Transform {
        get {
            return self.components[Transform.self]!
        }
        
        set {
            return self.components[Transform.self] = newValue
        }
    }
}
