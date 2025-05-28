//
//  RuntimeRegistrable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 31.05.2024.
//

// TODO: Add to macros. Want to use next syntax `@RuntimeRegistrable(Texture2D, AtlasTexture)`

@_spi(Runtime)
public protocol RuntimeRegistrable {
    @MainActor static func registerTypes()
}
