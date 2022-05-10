//
//  Transform.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

public struct Transform: Component {
    public var rotation: Quat

    public var scale: Vector3

    public var position: Vector3

    public var matrix: Transform3D {
        get {
            return Transform3D(scale: self.scale) * Transform3D(quat: self.rotation) * Transform3D(translation: self.position)
        }
        
        set {
            self.scale = newValue.scale
            self.rotation = newValue.rotation
            self.position = newValue.origin
        }
    }
    
    public init(rotation: Quat = .identity, scale: Vector3 = [1, 1, 1], position: Vector3 = .zero) {
        self.rotation = rotation
        self.scale = scale
        self.position = position
    }
}

public extension ScriptComponent {
    var transform: Transform {
        get {
            return self.components[Transform.self]!
        }
        
        set {
            return self.components[Transform.self] = newValue
        }
    }
}
