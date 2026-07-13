//
//  SpotlightComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/21/22.
//

import AdaECS
import Math

@Component
public struct SpotLightComponent: Sendable {
    public var radiance: Vector3
    public var intensity: Float
    public var castShadows: Bool

    public init(radiance: Vector3 = .one, intensity: Float = 1, castShadows: Bool = true) {
        self.radiance = radiance
        self.intensity = intensity
        self.castShadows = castShadows
    }
}

@Component
public struct PointLightComponent: Sendable {
    public var radiance: Vector3
    public var intensity: Float
    public var castShadows: Bool

    public init(radiance: Vector3 = .one, intensity: Float = 1, castShadows: Bool = true) {
        self.radiance = radiance
        self.intensity = intensity
        self.castShadows = castShadows
    }
}

/// An infinitely distant light. Its local +Z axis is the direction the light rays travel.
@Component
public struct DirectionalLightComponent: Sendable {
    public var radiance: Vector3
    public var intensity: Float
    public var castShadows: Bool
    public var shadowDistance: Float
    public var shadowBias: Float
    public var shadowSlopeBias: Float

    public init(
        radiance: Vector3 = .one,
        intensity: Float = 1,
        castShadows: Bool = true,
        shadowDistance: Float = 30,
        shadowBias: Float = 0.0008,
        shadowSlopeBias: Float = 0.003
    ) {
        self.radiance = radiance
        self.intensity = intensity
        self.castShadows = castShadows
        self.shadowDistance = shadowDistance
        self.shadowBias = shadowBias
        self.shadowSlopeBias = shadowSlopeBias
    }
}
