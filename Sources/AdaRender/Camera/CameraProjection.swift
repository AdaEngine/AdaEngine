//
//  CameraProjection.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 20.12.2025.
//

import AdaUtils
import Math

/// View projection for camera
public enum Projection: Sendable, Codable {
    /// Orthographic projection commonly used for 2D space.
    case orthographic(OrthographicProjection)

    /// Perspective projection used for 3D space.
    case perspective(PerspectiveProjection)
    case custom(CameraProjection)

    @inlinable
    public var cameraProjection: CameraProjection {
        switch self {
        case .orthographic(let orthographicProjection):
            return orthographicProjection
        case .perspective(let perspectiveProjection):
            return perspectiveProjection
        case .custom(let cameraProjection):
            return cameraProjection
        }
    }

    public init(from decoder: any Decoder) throws {
        fatalErrorMethodNotImplemented()
    }

    public func encode(to encoder: any Encoder) throws {
        fatalErrorMethodNotImplemented()
    }
}

extension Projection: CameraProjection {
    @inlinable
    public var near: Float {
        cameraProjection.near
    }

    @inlinable
    public var far: Float {
        cameraProjection.far
    }

    @inlinable
    public func makeClipView() -> Math.Transform3D {
        cameraProjection.makeClipView()
    }

    @inlinable
    public mutating func updateView(width: Float, height: Float) {
        switch self {
        case .orthographic(var orthographicProjection):
            orthographicProjection.updateView(width: width, height: height)
            self = .orthographic(orthographicProjection)
        case .perspective(var perspectiveProjection):
            perspectiveProjection.updateView(width: width, height: height)
            self = .perspective(perspectiveProjection)
        case .custom(var cameraProjection):
            cameraProjection.updateView(width: width, height: height)
            self = .custom(cameraProjection)
        }
    }
}

public struct OrthographicProjection: CameraProjection {
    /// The closest point relative to camera that drawing will occur.
    public var near: Float

    /// The closest point relative to camera that drawing will occur
    public var far: Float

    public var viewportOrigin: Vector2

    @MinValue(0.1)
    public var scale: Float = 1

    private var viewportSize: Size = .zero

    public init(
        near: Float = -1,
        far: Float = 1000,
        viewportOrigin: Vector2 = Vector2(0.5, 0.5),
        scale: Float = 1,
        viewportSize: Size = .zero
    ) {
        self.near = near
        self.far = far
        self.viewportOrigin = viewportOrigin
        self.scale = scale
        self.viewportSize = viewportSize
    }

    public func makeClipView() -> Transform3D {
        let totalHeight = (viewportSize.height / scale)
        let totalWidth = (viewportSize.width / scale)
        return Transform3D.orthographic(
            left: -totalWidth * viewportOrigin.x,
            right: totalWidth * (1 - viewportOrigin.x),
            top: totalHeight * (1 - viewportOrigin.y),
            bottom: -totalHeight * viewportOrigin.y,
            zNear: near,
            zFar: far
        )
    }

    public mutating func updateView(width: Float, height: Float) {
        assert(width > 0, "Width must be great zero")
        assert(height > 0, "Height must be great zero")
        self.viewportSize = Size(width: width, height: height)
    }
}

public struct PerspectiveProjection: CameraProjection {

    public var near: Float

    public var far: Float

    /// Angle of camera view
    public var fieldOfView: Angle

    public private(set) var aspectRation: Float

    public init(
        near: Float = -1,
        far: Float = 1000,
        fieldOfView: Angle = .degrees(70),
        aspectRation: Float = 16/9
    ) {
        self.near = near
        self.far = far
        self.fieldOfView = fieldOfView
        self.aspectRation = aspectRation
    }

    public func makeClipView() -> Transform3D {
        Transform3D.perspective(
            fieldOfView: fieldOfView,
            aspectRatio: aspectRation,
            zNear: near,
            zFar: far
        )
    }

    public mutating func updateView(width: Float, height: Float) {
        assert(width > 0, "Width must be great zero")
        assert(height > 0, "Height must be great zero")
        aspectRation = width / height
    }
}

/// Object that calculate camera projection
public protocol CameraProjection: Sendable, Codable {
    /// The closest point relative to camera that drawing will occur.
    var near: Float { get }

    /// The closest point relative to camera that drawing will occur
    var far: Float { get }

    /// Create a clip view.
    func makeClipView() -> Transform3D

    /// Update camera projection data.
    mutating func updateView(width: Float, height: Float)
}

public extension CameraProjection {
    func makeFrustum(from transform: Transform3D) -> Frustum {
        Frustum.make(from: self.makeClipView() * transform)
    }
}
