//
//  Camera.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public final class Camera: ScriptComponent {
    
    public enum Projection: UInt8, Codable, CaseIterable {
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
    public var viewportSize: Size = .zero
    
    /// Set camera is active
    @Export
    public var isPrimal = false
    
    @Export
    public var orthographicScale: Float = 1
    
    // MARK: Computed Properties
    
    public var isCurrent: Bool {
        return self.entity?.scene?.activeCamera === self
    }
    
    public var viewMatrix: Transform3D = .identity
    
    // MARK: - Internal
    
    func makeCameraData() -> CameraData {
        let projection: Transform3D
        let aspectRation = Float(viewportSize.width) / Float(viewportSize.height)
        
        switch self.projection {
        case .orthographic:
            
            projection = Transform3D.orthogonal(
                left: -aspectRation * self.orthographicScale,
                right: aspectRation * self.orthographicScale,
                top: self.orthographicScale,
                bottom: -self.orthographicScale,
                zNear: self.near,
                zFar: self.far
            )
        case .perspective:
            projection = Transform3D.perspective(
                fieldOfView: self.fieldOfView,
                aspectRatio: aspectRation,
                zNear: self.near,
                zFar: self.far
            )
        }
        
        return CameraData(viewProjection: projection * self.viewMatrix, position: self.transform.position)
    }
}

extension Camera {
    struct CameraData {
        var viewProjection: Transform3D = .identity
        var position: Vector3 = .zero
    }
}
