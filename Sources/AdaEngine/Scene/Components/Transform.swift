//
//  Transform.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

public struct Transform: Component {
    
    public var rotation: Quat {
        didSet {
            self.updateMatrix()
        }
    }

    public var scale: Vector3 {
        didSet {
            self.updateMatrix()
        }
    }

    public var position: Vector3 {
        didSet {
            self.updateMatrix()
        }
    }
    
    private var _matrix: Transform3D = .identity
    
    public init(
        rotation: Quat = .identity,
        scale: Vector3 = [1, 1, 1],
        position: Vector3 = .zero
    ) {
        self.rotation = rotation
        self.scale = scale
        self.position = position
        
        self.updateMatrix()
    }
    
    private mutating func updateMatrix() {
        self._matrix = Transform3D(
            translation: self.position,
            rotation: self.rotation,
            scale: self.scale
        )
    }
}

public extension Transform {
    var matrix: Transform3D {
        get {
            _matrix
        }
        
        set {
            self.scale = newValue.scale
            self.rotation = newValue.rotation
            self.position = newValue.origin
            
            self._matrix = newValue
        }
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
