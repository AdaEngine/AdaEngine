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
            return self.data.matrix
        }
        
        set {
            self.data.matrix = newValue
            self.data.status.insert(.dirtyGlobal)
        }
    }
    
    /// Return world trasform matrix
    public var worldTransform: Transform3D {
        
        let matrix = self.localTransform
        
        guard let parentTransform = self.entity?.parent?.components[Transform.self] else {
            return matrix
        }
        
        return matrix * parentTransform.worldTransform
    }
    
    public var parent: Transform? {
        guard let parentTransform = self.entity?.parent?.components[Transform.self] else {
            return nil
        }
        
        return parentTransform
    }
    
    public var position: Vector3 {
        get {
            self.updateLocalTransformIfNeeded()
            return self.data.matrix.origin
        }
        
        set {
            self.data.position = newValue
            self.data.status.insert(.dirtyLocal)
        }
    }
    
    /// The scale of the transform
    public var scale: Vector3 {
        get {
            self.updateLocalTransformIfNeeded()
            return data.matrix.scale
        }
        
        set {
            self.data.scale = newValue
            self.data.status.insert(.dirtyLocal)
            self.updateLocalTransformIfNeeded()
        }
    }
//    
//    public var rotation: Vector3 {
//        
//    }
    
    public var worldPosition: Vector3 {
        return self.worldTransform.origin
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
        if self.data.status.contains(.dirtyLocal) {
            let newMatrix = Transform3D(scale: self.data.scale) * Transform3D(quat: self.data.rotation) * Transform3D(translation: self.data.position)
            self.data.matrix = newMatrix
            self.data.status.remove(.dirtyLocal)
        }
        
        if self.data.status.contains(.dirtyGlobal) {
            self.data.scale = self.data.matrix.scale
            self.data.rotation = self.data.matrix.rotation
            self.data.position = self.data.matrix.origin
            
            self.data.status.remove(.dirtyGlobal)
        }
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
        var matrix: Transform3D = .identity
        
        var rotation: Quat = .identity
        var scale: Vector3 = .zero
        var position: Vector3 = .zero
        
        var status: TransformStatus = []
    }
}

public extension Component {
    var transform: Transform {
        // TODO: Maybe not efficent solution
        return self.components[Transform.self]!
    }
}
