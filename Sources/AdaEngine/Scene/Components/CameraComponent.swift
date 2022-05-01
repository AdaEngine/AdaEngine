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
    public var near: Float = 0.001
    
    /// The closest point relative to camera that drawing will occur
    public var far: Float = 100
    
    /// Angle of camera view
    public var fieldOfView: Angle = .degrees(70)
    
    /// Base projection in camera
    public var projection: Projection = .perspective
    
    // MARK: Computed Properties
    
    public var isCurrent: Bool {
        return CameraManager.shared.currentCamera === self
    }
    
    // MARK: - Public methods
    
    public func makeCurrent() {
        CameraManager.shared.setCurrentCamera(self)
    }
    
    // MARK: - Internal
    
    var matrix: Transform3D = .identity
    
    var viewMatrix: Transform3D = .identity
    
    // FIXME: Looks like stupid idea
    
    public override func update(_ deltaTime: TimeInterval) {
//        self.updateViewMatrixIfNeeded()
    }
    
    private func updateViewMatrixIfNeeded() {
        if self.matrix != self.transform.localTransform {
            self.matrix = self.transform.localTransform
            
            let translation = Transform3D(translation: self.transform.position)
            self.viewMatrix = translation.inverse
        }
    }
}

