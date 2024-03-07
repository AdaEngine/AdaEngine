//
//  SpriteComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/8/22.
//

/// Contains information about sprite, like texture and tint coloring.
@Component
public struct SpriteComponent {
    public var texture: Texture2D?
    public var tintColor: Color
    
    /// Create a new sprite component for specific texture and tintColor.
    /// - Parameter texture: Texture for rendering
    /// - Parameter tintColor: Color for tinting the texture. By default is white and don't tint a texture.
    public init(texture: Texture2D? = nil, tintColor: Color = .white) {
        self.texture = texture
        self.tintColor = tintColor
    }
}
