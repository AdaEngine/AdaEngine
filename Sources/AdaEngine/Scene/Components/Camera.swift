//
//  Camera.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public class Camera: ScriptComponent {
    
    public enum Projection: String, Codable, CaseIterable {
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
    
    @Export(skipped: true)
    public var viewportSize: Vector2i = .zero
    
    /// Set camera is active
    @Export
    public var isPrimal = false
    
    
    // MARK: Computed Properties
    
    public var isCurrent: Bool {
        return self.entity?.scene?.activeCamera === self
    }
    
    // MARK: - Internal
    
    var viewMatrix: Transform3D = .identity
    
    func makeCameraData() -> CameraData {
        let projection: Transform3D
        
        switch self.projection {
        case .orthographic:
            projection = Transform3D.orthogonal(
                left: Float(viewportSize.x / -2),
                right: Float(viewportSize.x / 2),
                top: Float(viewportSize.y / 2),
                bottom: Float(viewportSize.y / -2),
                zNear: self.near,
                zFar: self.far
            )
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

