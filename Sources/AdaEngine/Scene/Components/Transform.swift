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
        
        return matrix * parentTransform.worldTransform
    }
    
    public var parent: Transform? {
        guard let parentTransform = self.entity?.parent?.components[Transform] else {
            return nil
        }
        
        return parentTransform
    }
    
    public var localPosition: Vector3 {
        return Vector3(self.matrix[0, 3], self.matrix[1, 3], self.matrix[2, 3])
    }
    
    public var worldPosition: Vector3 {
        let position = self.localPosition
        
        guard let parentTransform = self.entity?.parent?.components[Transform] else {
            return position
        }
        
        return position * parentTransform.worldPosition
    }
    
    override init() {
        self.matrix = .identity
    }
    
    // MARK: - Public methods
    
    func lookAt(_ targetWorldPosition: Vector3, worldUp: Vector3 = .up) {
        let lookAtMatrix = Transform3D.lookAt(eye: targetWorldPosition, center: self.localPosition, up: worldUp)
        self.matrix *= lookAtMatrix
    }
    
}
