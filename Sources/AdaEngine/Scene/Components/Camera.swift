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
    public var near: Float = -1 {
        didSet {
            self.updateProjectionMatrix()
        }
    }
    
    /// The closest point relative to camera that drawing will occur
    @Export
    public var far: Float = 1 {
        didSet {
            self.updateProjectionMatrix()
        }
    }
    
    /// Angle of camera view
    @Export
    public var fieldOfView: Angle = .degrees(70) {
        didSet {
            self.updateProjectionMatrix()
        }
    }
    
    /// Base projection in camera
    @Export
    public var projection: Projection = .perspective {
        didSet {
            self.updateProjectionMatrix()
        }
    }
    
    /// A viewport where camera will render
    internal var viewport: Viewport? {
        didSet {
            self.updateProjectionMatrix()
            
            self.resizeEvent = nil
            
            if let viewport {
                self.resizeEvent = viewport.subscribe(to: ViewportEvents.DidResize.self, on: viewport, completion: self.onViewportResized(_:))
            }
        }
    }
    
    /// Camera frustum
    public internal(set) var frustum: Frustum = Frustum()
    
    /// Set camera is active
    @Export
    public var isActive = false
    
    /// Fill color for unused pixel.
    @Export
    public var backgroundColor: Color = .black
    
    @Export
    public var clearFlags: CameraClearFlags = .nothing
    
    @Export
    @MinValue(0.1)
    public var orthographicScale: Float = 1 {
        didSet {
            self.updateProjectionMatrix()
        }
    }
    
    // MARK: Computed Properties
    
    // TODO: Should we have this flag? Looks like isActive is enough for us
    public var isCurrent: Bool {
        return self.entity?.scene?.activeCamera === self
    }
    
    public var viewMatrix: Transform3D = .identity
    
    // MARK: - Internal
    
    private var resizeEvent: AnyCancellable?
    
    internal private(set) var projectionMatrix: Transform3D = .identity
    
    func makeCameraData() -> CameraData {
        let viewMatrix = self.entity.flatMap { entity in
            entity.scene?.worldTransformMatrix(for: entity)
        } ?? .identity
        
        return CameraData(
            projection: self.projectionMatrix,
            viewProjection: self.projectionMatrix * viewMatrix.inverse,
            position: self.transform.position
        )
    }
    
    private func updateProjectionMatrix() {
        let viewportSize = self.viewport?.size ?? .zero
        
        let projection: Transform3D
        let aspectRation = viewportSize.width / viewportSize.height
        
        switch self.projection {
        case .orthographic:
            projection = Transform3D.orthographic(
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
        
        self.projectionMatrix = projection
    }
    
    // TODO: (Vlad) looks like we should update projection in CameraSystem
    private func onViewportResized(_ event: ViewportEvents.DidResize) {
        self.updateProjectionMatrix()
    }
}

extension Camera {
    struct CameraData {
        let projection: Transform3D
        let viewProjection: Transform3D
        let position: Vector3
    }
}
