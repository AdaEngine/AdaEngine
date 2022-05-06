//
//  Camera.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public class Camera: Component {
    
    public enum Projection: String, Codable {
        case perspective
        case orthographic
    }
    
    private var isDirty = false
    
    // MARK: Properties
    
    /// The closest point relative to camera that drawing will occur.
    @Export
    public var near: Float = 0.001
    
    /// The closest point relative to camera that drawing will occur
    @Export
    public var far: Float = 100
    
    /// Angle of camera view
    @Export
    public var fieldOfView: Angle = .degrees(70)
    
    /// Base projection in camera
    @Export
    public var projection: Projection = .perspective
    
    @Export
    public var viewportSize: Vector2i = .zero
    
    // MARK: Computed Properties
    
    public var isCurrent: Bool {
        return CameraManager.shared.currentCamera === self
    }
    
    // MARK: - Public methods
    
    public func makeCurrent() {
        CameraManager.shared.setCurrentCamera(self)
    }
    
    // MARK: - Internal
    
    var viewMatrix: Transform3D = .identity
    
    func makeCameraData() -> CameraData {
        let projection: Transform3D
        
        switch self.projection {
        case .orthographic:
            projection = .identity
        case .perspective:
            projection = Transform3D.perspective(
                fieldOfView: self.fieldOfView,
                aspectRatio: Float(viewportSize.x) / Float(viewportSize.y),
                zNear: self.near,
                zFar: self.far
            )
        }
        
        let position = self.transform.position
        
        return CameraData(projection: projection, view: self.viewMatrix, position: position)
    }
}

