//
//  AdaEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/14/21.
//

/// Main events available from the engine.
public enum EngineEvents {
    /// Called each time, when main game loop was iterating.
    public struct GameLoopBegan: Event {
        /// The delta time after previous tick.
        public let deltaTime: TimeInterval
    }
    
    public struct FramesPerSecondEvent: Event {
        public let framesPerSecond: Int
    }
}

public final class Engine {
    
    nonisolated(unsafe) public static let shared: Engine = Engine()
    
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
