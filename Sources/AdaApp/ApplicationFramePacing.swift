//
//  ApplicationFramePacing.swift
//  AdaEngine
//
//  Created by Codex on 24.05.2026.
//

import AdaECS
import AdaUtils

/// Controls how often the platform application loop should advance the app world.
public struct ApplicationFramePacing: Resource, Codable, Sendable {
    /// Maximum number of app-world updates per second.
    public var maximumFramesPerSecond: Int

    /// Minimum time between app-world updates.
    public var minimumFrameDuration: LongTimeInterval {
        1 / LongTimeInterval(maximumFramesPerSecond)
    }

    /// Creates frame pacing settings.
    /// - Parameter maximumFramesPerSecond: Maximum number of app-world updates per second.
    public init(maximumFramesPerSecond: Int) {
        self.maximumFramesPerSecond = max(1, maximumFramesPerSecond)
    }
}
