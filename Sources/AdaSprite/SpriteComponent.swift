//
//  Sprite.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/8/22.
//

import AdaECS
import AdaAssets
import AdaRender
import AdaUtils

/// Contains information about sprite, like texture and tint coloring.
@Component
public struct Sprite: Codable {
    public var texture: AssetHandle<Texture2D>?
    public var tintColor: Color
    public var flipX: Bool = false
    public var flipY: Bool = false

    /// Create a new sprite component for specific texture and tintColor.
    /// - Parameter texture: Asset that contains texture.
    /// - Parameter tintColor: Color for tinting the texture. By default is white and don't tint a texture.
    /// - Parameter flipX: Flip texture horizontally
    /// - Parameter flipY: Flip texture vertically.
    public init(
        texture: AssetHandle<Texture2D>? = nil,
        tintColor: Color = .white,
        flipX: Bool = false,
        flipY: Bool = false
    ) {
        self.texture = texture
        self.tintColor = tintColor
        self.flipX = flipX
        self.flipY = flipY
    }

    /// Create a new sprite component for specific texture and tintColor.
    /// - Parameter texture: Texture for rendering.
    /// - Parameter tintColor: Color for tinting the texture. By default is white and don't tint a texture.
    /// - Parameter flipX: Flip texture horizontally
    /// - Parameter flipY: Flip texture vertically.
    public init(
        texture: Texture2D,
        tintColor: Color = .white,
        flipX: Bool = false,
        flipY: Bool = false
    ) {
        self.texture = AssetHandle(texture)
        self.tintColor = tintColor
        self.flipX = flipX
        self.flipY = flipY
    }
}
