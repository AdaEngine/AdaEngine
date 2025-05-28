//
//  EngineEvents.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 28.05.2025.
//

/// Main events available from the engine.
public enum EngineEvents {
    /// Called each time, when main main loop was iterating.
    public struct MainLoopBegan: Event {
        /// The delta time after previous tick.
        public let deltaTime: TimeInterval

        public init(deltaTime: TimeInterval) {
            self.deltaTime = deltaTime
        }
    }

    public struct FramesPerSecondEvent: Event {
        public let framesPerSecond: Int

        public init(framesPerSecond: Int) {
            self.framesPerSecond = framesPerSecond
        }
    }
}
