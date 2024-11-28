//
//  RuntimeRegistrable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 31.05.2024.
//

// TODO: Add to macros. Want to use next syntax `@RuntimeRegistrable(Texture2D, AtlasTexture)`

@_spi(Runtime)
public protocol RuntimeRegistrable {
    static func registerTypes()
}

enum RuntimeTypeLoader {
    
    /// Load type in memory to great decoding/encoding
    @MainActor
    static func loadTypes() {
        TileMap.registerTypes()
        Texture.registerTypes()
    }
}
