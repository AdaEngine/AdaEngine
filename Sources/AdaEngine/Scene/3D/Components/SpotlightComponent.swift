//
//  SpotlightComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/21/22.
//

import Math

@Component
public struct SpotLightComponent {
    public var radiance: Vector3 = .one
    public var intensity: Float = 1
    public var castShadows = true
}

@Component
public struct PointLightComponent {
    public var radiance: Vector3 = .one
    public var intensity: Float = 1
    public var castShadows = true
}

@Component
public struct DirectionalLightComponent {
    public var radiance: Vector3 = .one
    public var intensity: Float = 1
    public var castShadows = true
}
