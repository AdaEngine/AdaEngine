//
//  Circle2DComponent.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

public struct Circle2DComponent: Component {
    public var color: Color
    public var thickness: Float
    public var fade: Float
    
    public init(color: Color, thickness: Float = 1, fade: Float = 0.005) {
        self.color = color
        self.thickness = thickness
        self.fade = fade
    }
}
