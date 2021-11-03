//
//  CameraComponent.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public class CameraComponent: Component {
    
    public enum Projection: UInt {
        case perspective
        case orthographic
    }
    
    // MARK: Properties
    
    /// The closest point relative to camera that drawing will occur.
    public var near: Float = 0.1
    
    /// The closest point relative to camera that drawing will occur
    public var far: Float = 100
    
    /// Angle of camera view
    public var fieldOfView: Angle = .radians(45)
    
    /// Base projection in camera
    public var projection: Projection = .perspective
    
    // MARK: Computed Properties
    
    public var isCurrent: Bool {
        // TODO: Remove when create CameraManager
        return true
    }
    
    @RequiredComponent private var transform: Transform
    
    // MARK: - Component lifecycle
    
    public override func update(_ deltaTime: TimeInterval) {
        
    }
    
    // MARK: - Public methods
    
    public func makeCurrent() {
        // TODO: Add to CameraManager
    }
    
}

