//
//  AdaEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/14/21.
//

import AdaUtils
@_spi(Runtime) import AdaRender

enum RuntimeTypeLoader {

    /// Load type in memory to great decoding/encoding
    @MainActor
    static func loadTypes() {
//        TileMap.registerTypes()
        Texture.registerTypes()
//        RegistredComponent.registerTypes()
    }
}

/// The main engine class.
public final class Engine {
    
    /// The shared engine instance.
    nonisolated(unsafe) public static let shared: Engine = Engine()
    
    /// Initialize a new engine instance.
    private init() { }
    
    /// Setup physics ticks per second. Default value is equal 60 ticks per second.
    public var physicsTickPerSecond: Int = 60
    
    /// Engine version
    public var engineVersion: Version = Version(string: "0.1.0")

    internal var useValidationLayers: Bool {
        #if DEBUG && VULKAN
        return true
        #else
        return false
        #endif
    }
}
