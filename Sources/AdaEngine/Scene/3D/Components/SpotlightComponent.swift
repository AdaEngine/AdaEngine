//
//  SpotlightComponent.swift
//  
//
//  Created by v.prusakov on 8/21/22.
//

import Math

public struct SpotLightComponent: Component {
    public var radiance: Vector3 = .one
    public var intensity: Float = 1
    public var castShadows = true
}

public struct PointLightComponent: Component {
    public var radiance: Vector3 = .one
    public var intensity: Float = 1
    public var castShadows = true
}

public struct DirectionalLightComponent: Component {
    public var radiance: Vector3 = .one
    public var intensity: Float = 1
    public var castShadows = true
}
