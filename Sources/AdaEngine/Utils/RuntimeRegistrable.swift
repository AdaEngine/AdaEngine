//
//  RuntimeRegistrable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 31.05.2024.
//

@_spi(Runtime)
public protocol RuntimeRegistrable {
    static func registerTypes()
}

enum RuntimeTypeLoader {
    
    /// Load type in memory to great decoding/encoding
    static func loadTypes() {
        TileMap.registerTypes()
        Texture.registerTypes()
    }
}
