//
//  SpriteComponent.swift
//  
//
//  Created by v.prusakov on 5/8/22.
//

public struct SpriteComponent: Component {
    public var texture: Texture2D
    
    public init(texture: Texture2D) {
        self.texture = texture
    }
}
