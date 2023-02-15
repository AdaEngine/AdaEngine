//
//  Camera.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//
//

public struct Viewport: Codable, Equatable {
    public var rect: Rect
    public var depth: ClosedRange<Float>

    init(rect: Rect = Rect.zero, depth: ClosedRange<Float> = Float(0.0)...Float(1.0)) {
        self.rect = rect
        self.depth = depth
    }
}

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
public struct Camera: Component {
    
    public enum Projection: UInt8, Codable, CaseIterable {
        case perspective
        case orthographic
    }
    
    public enum RenderTarget: Codable {
        case window(Window.ID)
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
    public var backgroundColor: Color = .black
    
    @Export
    public var clearFlags: CameraClearFlags = .nothing
    
    @Export
    @MinValue(0.1)
    public var orthographicScale: Float = 1
    
    public internal(set) var renderTarget: RenderTarget
    
    @NoExport
    public internal(set) var computedData: CameraComputedData
    
    // MARK: - Init
    
    public init(renderTarget: RenderTexture, viewport: Viewport? = nil) {
        self.renderTarget = .texture(renderTarget)
        self.viewport = viewport
    }
    
    public init() {
        self.renderTarget = .window(.empty)
    }
    
    public var viewMatrix: Transform3D = .identity
    
    func makeCameraData(transform: Transform) -> CameraData {
        let projectionMatrix = self.computedData.projectionMatrix
        
        return CameraData(
            projection: projectionMatrix,
            viewProjection: projectionMatrix * viewMatrix,
            position: transform.position
        )
    }
}

extension Camera {
    struct CameraData {
        let projection: Transform3D
        let viewProjection: Transform3D
        let position: Vector3
    }
    
    public struct CameraComputedData: DefaultValue {
        
        public static var defaultValue: Camera.CameraComputedData = .init()
        
        public internal(set) var projectionMatrix: Transform3D = .identity
        public internal(set) var viewMatrix: Transform3D = .identity
        public internal(set) var frustum: Frustum = Frustum()
    }
}
