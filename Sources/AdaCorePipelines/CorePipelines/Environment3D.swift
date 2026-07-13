//
//  Environment3D.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
import AdaRender
import AdaUtils

/// Describes a sky rendered behind a 3D scene.
public struct Skybox3D: Codable, Sendable {
    /// Optional equirectangular (longitude/latitude) environment texture.
    public var texture: AssetHandle<Texture2D>?
    public var zenithColor: Color
    public var horizonColor: Color
    public var groundColor: Color
    public var intensity: Float
    public var isEnabled: Bool

    public init(
        texture: AssetHandle<Texture2D>? = nil,
        zenithColor: Color = Color(red: 0.12, green: 0.28, blue: 0.55),
        horizonColor: Color = Color(red: 0.62, green: 0.72, blue: 0.82),
        groundColor: Color = Color(red: 0.08, green: 0.09, blue: 0.11),
        intensity: Float = 1,
        isEnabled: Bool = true
    ) {
        self.texture = texture
        self.zenithColor = zenithColor
        self.horizonColor = horizonColor
        self.groundColor = groundColor
        self.intensity = intensity
        self.isEnabled = isEnabled
    }
}

/// Quality and appearance controls for screen-space reflections.
public struct ScreenSpaceReflection: Codable, Sendable {
    public var isEnabled: Bool
    /// Maximum ray length in view-space units.
    public var maxDistance: Float
    /// Distance between ray-marching samples in view-space units.
    public var stride: Float
    /// Depth tolerance used to accept an intersection.
    public var thickness: Float
    /// Maximum number of samples. Values above 64 are clamped by the shader.
    public var maxSteps: Int
    public var intensity: Float
    /// Width of the screen-edge fade in normalized UV coordinates.
    public var edgeFade: Float

    public init(
        isEnabled: Bool = true,
        maxDistance: Float = 35,
        stride: Float = 0.25,
        thickness: Float = 0.18,
        maxSteps: Int = 48,
        intensity: Float = 0.7,
        edgeFade: Float = 0.08
    ) {
        self.isEnabled = isEnabled
        self.maxDistance = maxDistance
        self.stride = stride
        self.thickness = thickness
        self.maxSteps = maxSteps
        self.intensity = intensity
        self.edgeFade = edgeFade
    }
}

/// Environment settings consumed by the main 3D render graph.
@Component
public struct Environment3D: Codable, Sendable {
    public var skybox: Skybox3D
    public var screenSpaceReflection: ScreenSpaceReflection

    public init(
        skybox: Skybox3D = Skybox3D(),
        screenSpaceReflection: ScreenSpaceReflection = ScreenSpaceReflection()
    ) {
        self.skybox = skybox
        self.screenSpaceReflection = screenSpaceReflection
    }
}

/// Extracted environments keyed by the source camera entity.
public struct ExtractedEnvironment3D: Resource, Sendable {
    public var environments: [Entity.ID: Environment3D] = [:]

    public init() {}
}

@System
public func ExtractEnvironment3D(
    _ query: Extract<Query<Entity, Environment3D>>,
    _ extracted: ResMut<ExtractedEnvironment3D>
) {
    extracted.environments.removeAll(keepingCapacity: true)
    query.wrappedValue.forEach { entity, environment in
        extracted.environments[entity.id] = environment
    }
}
