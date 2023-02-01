//
//  Camera.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public struct CameraClearFlags: OptionSet, Codable {
    public var rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let solid = CameraClearFlags(rawValue: 1 << 0)
    
    public static let depthBuffer = CameraClearFlags(rawValue: 1 << 1)
    
    public static let nothing: CameraClearFlags = []
}

// TODO: We should translate mouse coordinate space to scene coordinate space
// FIXME: Change camera to component, instead of script component
public final class Camera: ScriptComponent {
    
    public enum Projection: UInt8, Codable, CaseIterable {
        case perspective
        case orthographic
    }
    
    // MARK: Properties
    
    /// The closest point relative to camera that drawing will occur.
    @Export
    public var near: Float = 0.001
    
    /// The closest point relative to camera that drawing will occur
    @Export
    public var far: Float = 1000
    
    /// Angle of camera view
    @Export
    public var fieldOfView: Angle = .degrees(70)
    
    /// Base projection in camera
    @Export
    public var projection: Projection = .perspective
    
    /// A viewport where camera will render
    internal var viewport: Viewport?
    
    /// Set camera is active
    @Export
    public var isActive = false
    
    /// Fill color for unused pixel.
    @Export
    public var backgroundColor: Color = .black
    
    @Export
    public var clearFlags: CameraClearFlags = .nothing
    
    @Export
    public var orthographicScale: Float = 1
    
    // MARK: Computed Properties
    
    // TODO: Should we have this flag? Looks like isActive is enough for us
    public var isCurrent: Bool {
        return self.entity?.scene?.activeCamera === self
    }
    
    public var viewMatrix: Transform3D = .identity
    
    // MARK: - Internal
    
    func makeCameraData() -> CameraData {
        let viewportSize = self.viewport?.size ?? .zero
        
        let projection: Transform3D
        let aspectRation = Float(viewportSize.width) / Float(viewportSize.height)
        
        switch self.projection {
        case .orthographic:
            // TODO: (Vlad) not works when use translate position
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
        
        let viewMatrix = self.entity.flatMap { entity in
            entity.scene?.worldTransformMatrix(for: entity)
        } ?? .identity
        
        return CameraData(
            viewProjection: projection * viewMatrix,
            position: self.transform.position
        )
    }
}

extension Camera {
    struct CameraData {
        var viewProjection: Transform3D = .identity
        var position: Vector3 = .zero
    }
}
