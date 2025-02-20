//
//  Camera.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

import Math

public struct Viewport: Codable, Equatable {
    public var rect: Rect
    public var depth: ClosedRange<Float>

    public init(rect: Rect = Rect.zero, depth: ClosedRange<Float> = Float(0.0)...Float(1.0)) {
        self.rect = rect
        self.depth = depth
    }
}

public struct CameraClearFlags: OptionSet, Codable, Sendable {
    public var rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let solid = CameraClearFlags(rawValue: 1 << 0)
    
    public static let depthBuffer = CameraClearFlags(rawValue: 1 << 1)
    
    public static let nothing: CameraClearFlags = []
}

// TODO: We should translate mouse coordinate space to scene coordinate space
/// This component represent camera on scene. You can create more than one camera for rendering.
/// Each camera has frustum, projection data.
@Component
public struct Camera: Sendable {

    /// View projection for camera
    public enum Projection: UInt8, Codable, CaseIterable, Sendable {
        /// Perspective projection used for 3D space.
        case perspective
        
        /// Orthographic projection commonly used for 2D space.
        case orthographic
    }
    
    /// Render target where camera will render.
    public enum RenderTarget: Codable, Sendable {
        
        /// Render camera to window.
        case window(UIWindow.ID)
        
        /// Render camera to texture.
        case texture(RenderTexture)
    }
    
    // MARK: Properties
    
    /// The closest point relative to camera that drawing will occur.
    @Export
    public var near: Float = -1
    
    /// The closest point relative to camera that drawing will occur
    @Export
    public var far: Float = 1
    
    /// Angle of camera view
    @Export
    public var fieldOfView: Angle = .degrees(70)
    
    /// Base projection in camera
    @Export
    public var projection: Projection = .perspective
    
    @Export
    public var viewport: Viewport?
    
    /// Set camera is active
    @Export
    public var isActive = false
    
    /// Fill color for unused pixel.
    @Export
    public var backgroundColor: Color = .surfaceClearColor

    /// Contains information about clear flags.
    /// By default contains ``CameraClearFlags/solid`` flag which fill clear color by ``Camera/backgroundColor``.
    @Export
    public var clearFlags: CameraClearFlags = .solid
    
    @Export
    @MinValue(0.1)
    public var orthographicScale: Float = 1
    
    /// Render target for camera.
    /// - Note: You should check that render target will not change while rendering.
    public internal(set) var renderTarget: RenderTarget
    
    @NoExport
    public internal(set) var computedData: CameraComputedData
    
    public var renderOrder: Int = 0
    
    // MARK: - Init
    
    /// Create a new camera component with specific render target and viewport.
    public init(renderTarget: RenderTexture, viewport: Viewport? = nil) {
        self.renderTarget = .texture(renderTarget)
        self.viewport = viewport
    }
    
    /// Create a new camera component. By default render target is window.
    public init() {
        self.renderTarget = .window(.empty)
    }
    
    public init(window: UIWindow.ID) {
        self.renderTarget = .window(window)
    }
    
    public var viewMatrix: Transform3D = .identity
}

public extension Camera {
    
    /// Normalized Device Coordinate to world point
    func ndcToWorld(cameraGlobalTransform: Transform3D, ndc: Vector3) -> Vector3 {
        let matrix = cameraGlobalTransform * self.computedData.projectionMatrix.inverse
        return (matrix * Vector4(ndc, 1)).xyz
    }
    
    /// Return point from world to Normalized Device Coordinate.
    func worldToNdc(cameraGlobalTransform: Transform3D, worldPosition: Vector3) -> Vector3 {
        let matrix = self.computedData.projectionMatrix * cameraGlobalTransform.inverse
        return (matrix * Vector4(worldPosition, 1)).xyz
    }
    
    /// Return point from viewport to 2D world.
    func viewportToWorld2D(cameraGlobalTransform: Transform3D, viewportPosition: Vector2) -> Vector2? {
        guard let viewport = self.viewport else {
            return nil
        }
        
        let ndc = viewportPosition * 2 / viewport.rect.size.asVector2 - Vector2.one
        let worldPlane = self.ndcToWorld(cameraGlobalTransform: cameraGlobalTransform, ndc: Vector3(ndc, 1))
        
        return worldPlane.xy
    }
    
    /// Return ray from viewport to world. More prefer for 3D space.
    func viewportToWorld(cameraGlobalTransform: Transform3D, point: Vector2) -> Ray? {
        guard let viewport = self.viewport else {
            return nil
        }
        
        let ndc = point * 2 / viewport.rect.size.asVector2 - Vector2.one
        let ndcToWorld = cameraGlobalTransform * self.computedData.projectionMatrix.inverse
        
        let worldPlaneNear = ndcToWorld * Vector4(Vector3(ndc, 1), 1)
        let worldPlaneFar = ndcToWorld * Vector4(Vector3(ndc, Float.greatestFiniteMagnitude), 1)
        
        if worldPlaneNear.isNaN && worldPlaneFar.isNaN {
            return nil
        }
        
        return Ray(
            origin: worldPlaneNear.xyz,
            direction: (worldPlaneFar - worldPlaneNear).xyz.normalized
        )
    }
    
    /// Return point from world to viewport.
    func worldToViewport(cameraGlobalTransform: Transform3D, worldPosition: Vector3) -> Vector2? {
        guard let viewport = self.viewport else {
            return nil
        }
        
        let size = viewport.rect.size.asVector2
        let ndcSpace = self.worldToNdc(cameraGlobalTransform: cameraGlobalTransform, worldPosition: worldPosition)
         
        if ndcSpace.z < 0 || ndcSpace.z > 1.0 {
            return nil
        }
        
        return ndcSpace.xy + Vector2.one / 2.0 * size
    }
    
}

extension Camera {
    public struct CameraComputedData: DefaultValue, Sendable {

        public static let defaultValue: Camera.CameraComputedData = .init()

        public internal(set) var projectionMatrix: Transform3D = .identity
        public internal(set) var viewMatrix: Transform3D = .identity
        public internal(set) var frustum: Frustum = Frustum()
        public internal(set) var targetScaleFactor: Float = 1
    }
}

@Component
public struct GlobalViewUniform {
    public internal(set) var projectionMatrix: Transform3D = .identity
    public internal(set) var viewProjectionMatrix: Transform3D = .identity
    public internal(set) var viewMatrix: Transform3D = .identity
}

@Component
struct GlobalViewUniformBufferSet {
    let uniformBufferSet: UniformBufferSet
    
    init() {
        self.uniformBufferSet = RenderEngine.shared.renderDevice.createUniformBufferSet()
        self.uniformBufferSet.label = "Global View Uniform"
        self.uniformBufferSet.initBuffers(for: GlobalViewUniform.self, binding: GlobalBufferIndex.viewUniform, set: 0)
    }
}
