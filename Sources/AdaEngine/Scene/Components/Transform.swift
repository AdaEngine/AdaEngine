//
//  Transform.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Math

/// Component contains information about entity position in world space
public class Transform: Component {
    
    /// Return current transform matrix
    public var matrix: Transform3D
    
    /// Return world trasform matrix
    public var worldTransform: Transform3D {
        
        let matrix = self.matrix
        
        guard let parentTransform = self.entity?.parent?.components[Transform] else {
            return matrix
        }
        
        return parentTransform.worldTransform * matrix
    }
    
    public var parent: Transform? {
        guard let parentTransform = self.entity?.parent?.components[Transform] else {
            return nil
        }
        
        return parentTransform
    }
    
    public var position: Vector3 {
        get {
            return Vector3(self.matrix[0, 3], self.matrix[1, 3], self.matrix[2, 3])
        }
        
        set {
            
            var matrix = self.matrix
            
            matrix[0, 3] = newValue.x
            matrix[1, 3] = newValue.y
            matrix[2, 3] = newValue.z
            
            self.matrix = matrix
        }
    }
    
    /// The scale of the transform
    public var scale: Vector3 {
        get {
            return Vector3(matrix[0, 1], matrix[1, 1], matrix[2, 2])
        }
        
        set {
            var matrix = self.matrix
            matrix[0, 1] = newValue.x
            matrix[1, 1] = newValue.y
            matrix[2, 2] = newValue.z
            
            self.matrix = matrix
        }
    }
    
    public var rotation: Quat {
        get {
            return Quat(rotationMatrix: self.matrix)
        }
        
        set {
            fatalError()
        }
    }
    
    public var worldPosition: Vector3 {
        let position = self.position
        
        guard let parentTransform = self.entity?.parent?.components[Transform] else {
            return position
        }
        
        return parentTransform.worldPosition * position
    }
    
    override init() {
        self.matrix = .identity
    }
    
    // MARK: - Public methods
    
    public func lookAt(_ targetWorldPosition: Vector3, worldUp: Vector3 = .up) {
        let lookAtMatrix = Transform3D.lookAt(eye: targetWorldPosition, center: self.worldPosition, up: worldUp)
        
        let scale = self.scale
        self.matrix = lookAtMatrix
        self.scale = scale
    }
    
    public func rotate(_ angle: Angle, axis: Vector3) {
        let rotate = self.matrix.rotate(angle: angle, axis: axis)
        self.matrix = rotate
    }
    
    public func rotateX(_ angle: Angle) {
        let rotate = self.matrix.rotate(angle: angle, axis: Vector3(1, 0, 0))
        self.matrix = rotate
    }
    
    public func rotateY(_ angle: Angle) {
        let rotate = self.matrix.rotate(angle: angle, axis: Vector3(0, 1, 0))
        self.matrix = rotate
    }
    
    public func rotateZ(_ angle: Angle) {
        let rotate = self.matrix.rotate(angle: angle, axis: Vector3(0, 0, 1))
        self.matrix = rotate
    }
    
}

public extension Component {
    var transform: Transform {
        // TODO: Maybe not efficent solution
        return self.components[Transform]!
    }
}
