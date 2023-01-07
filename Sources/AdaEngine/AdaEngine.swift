//
//  AdaEngine.swift
//
//
//  Created by v.prusakov on 8/14/21.
//

/// Main events available from the engine.
public enum EngineEvent {
    /// Called each time, when main game loop was iterating.
    public struct GameLoopBegan: Event {
        /// The delta time after previous tick.
        public let deltaTime: TimeInterval
    }
    
    public struct FramesPerSecondEvent: Event {
        public let framesPerSecond: Int
    }
}
