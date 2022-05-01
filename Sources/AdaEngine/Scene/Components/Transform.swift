//
//  Transform.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Math

/// Component contains information about entity position in world space
public class Transform: Component {
    
    private var data: TransformData
    
    /// Return current transform matrix
    public var localTransform: Transform3D {
        get {
            self.updateLocalTransformIfNeeded()
            
            return self.data.localTransform
        }
        
        set {
            self.data.localTransform = newValue
        }
    }
    
    /// Return world trasform matrix
    public var worldTransform: Transform3D {
        
        let matrix = self.localTransform
        
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
            return self.data.localTransform.origin
        }
        
        set {
            self.data.localTransform.origin = newValue
        }
    }
    
    /// The scale of the transform
    public var scale: Vector3 {
        get {
            return data.localTransform.scale
        }
        
        set {
            self.data.localTransform.scale = newValue
        }
    }
//    
//    public var rotation: Vector3 {
//        
//    }
    
    public var worldPosition: Vector3 {
        let position = self.position
        
        guard let parentTransform = self.entity?.parent?.components[Transform] else {
            return position
        }
        
        return parentTransform.worldPosition * position
    }
    
    override init() {
        self.data = TransformData()
    }
    
    // MARK: - Public methods
    
    public func lookAt(_ targetWorldPosition: Vector3, worldUp: Vector3 = .up) {
        let lookAtMatrix = Transform3D.lookAt(eye: targetWorldPosition, center: self.worldPosition, up: worldUp)
        
        let scale = self.scale
        self.localTransform = lookAtMatrix
        self.scale = scale
    }
    
    public func rotate(_ angle: Angle, axis: Vector3) {
        let rotate = self.localTransform.rotate(angle: angle, axis: axis)
        self.localTransform = rotate
    }
    
    public func rotateX(_ angle: Angle) {
        let rotate = self.localTransform.rotate(angle: angle, axis: Vector3(1, 0, 0))
        self.localTransform = rotate
    }
    
    public func rotateY(_ angle: Angle) {
        let rotate = self.localTransform.rotate(angle: angle, axis: Vector3(0, 1, 0))
        self.localTransform = rotate
    }
    
    public func rotateZ(_ angle: Angle) {
        let rotate = self.localTransform.rotate(angle: angle, axis: Vector3(0, 0, 1))
        self.localTransform = rotate
    }
    
    // MARK: - Private
    
    func updateLocalTransformIfNeeded() {
        guard self.data.status.contains(.dirtyLocal) else {
            return
        }
        
        self.data.status.remove(.dirtyLocal)
    }
    
}

extension Transform {
    
    struct TransformStatus: OptionSet {
        let rawValue: UInt8
        
        static let dirtyLocal = TransformStatus(rawValue: 1 << 0)
        static let dirtyGlobal = TransformStatus(rawValue: 1 << 1)
        static let none: TransformStatus = []
    }
    
    struct TransformData {
        var localTransform: Transform3D = .identity
        var worldTransform: Transform3D = .identity
        
        var rotation: Vector3 = .zero
        var scale: Vector3 = .zero
        
        var status: TransformStatus = []
    }
}

public extension Component {
    var transform: Transform {
        // TODO: Maybe not efficent solution
        return self.components[Transform]!
    }
}
