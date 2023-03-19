//
//  SpriteComponent.swift
//  
//
//  Created by v.prusakov on 5/8/22.
//

public struct SpriteComponent: Component {
    public var texture: Texture2D?
    public var tintColor: Color
    
    public init(texture: Texture2D? = nil, tintColor: Color = .white) {
        self.texture = texture
        self.tintColor = tintColor
    }
}

public struct CanvasComponent: Component {
    public var material: Material
    
    public init(material: Material) {
        self.material = material
    }
}
