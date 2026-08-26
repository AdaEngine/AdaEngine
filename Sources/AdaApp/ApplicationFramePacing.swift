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
    /// Maximum number of app-world updates per second, or the fallback limit when
    /// ``synchronizesWithDisplayRefreshRate`` is enabled.
    public var maximumFramesPerSecond: Int

    /// Whether display-linked platforms should use the display's maximum refresh rate.
    ///
    /// The configured ``maximumFramesPerSecond`` remains the fallback on platforms that
    /// do not expose display refresh information.
    public var synchronizesWithDisplayRefreshRate: Bool

    /// Minimum time between app-world updates for fixed-rate and fallback loops.
    public var minimumFrameDuration: LongTimeInterval {
        1 / LongTimeInterval(maximumFramesPerSecond)
    }

    /// Creates frame pacing settings.
    /// - Parameters:
    ///   - maximumFramesPerSecond: Maximum number of app-world updates per second.
    ///   - synchronizesWithDisplayRefreshRate: Whether display-linked platforms should
    ///     prefer the display's maximum refresh rate.
    public init(
        maximumFramesPerSecond: Int,
        synchronizesWithDisplayRefreshRate: Bool = false
    ) {
        self.maximumFramesPerSecond = max(1, maximumFramesPerSecond)
        self.synchronizesWithDisplayRefreshRate = synchronizesWithDisplayRefreshRate
    }

    /// Creates frame pacing that follows the active display refresh rate where supported.
    ///
    /// iPhone app targets must also set `CADisableMinimumFrameDurationOnPhone` to `true`
    /// in their Info.plist to opt in to update rates above 60 Hz.
    /// - Parameter fallbackMaximumFramesPerSecond: The update limit used on platforms
    ///   without display refresh information.
    public static func displaySynchronized(
        fallbackMaximumFramesPerSecond: Int = 60
    ) -> Self {
        Self(
            maximumFramesPerSecond: fallbackMaximumFramesPerSecond,
            synchronizesWithDisplayRefreshRate: true
        )
    }

    /// Resolves the maximum update rate for a display.
    /// - Parameter displayMaximumFramesPerSecond: Maximum refresh rate reported by the display.
    public func resolvedMaximumFramesPerSecond(
        forDisplayMaximumFramesPerSecond displayMaximumFramesPerSecond: Int
    ) -> Int {
        let displayMaximumFramesPerSecond = max(1, displayMaximumFramesPerSecond)
        if synchronizesWithDisplayRefreshRate {
            return displayMaximumFramesPerSecond
        }
        return min(maximumFramesPerSecond, displayMaximumFramesPerSecond)
    }

    /// Resolves an adaptive frame-rate range for a display-linked update loop.
    public func resolvedFrameRateRange(
        forDisplayMaximumFramesPerSecond displayMaximumFramesPerSecond: Int
    ) -> ClosedRange<Int> {
        let maximum = resolvedMaximumFramesPerSecond(
            forDisplayMaximumFramesPerSecond: displayMaximumFramesPerSecond
        )
        return min(30, maximum)...maximum
    }

    private enum CodingKeys: String, CodingKey {
        case maximumFramesPerSecond
        case synchronizesWithDisplayRefreshRate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            maximumFramesPerSecond: try container.decode(Int.self, forKey: .maximumFramesPerSecond),
            synchronizesWithDisplayRefreshRate: try container.decodeIfPresent(
                Bool.self,
                forKey: .synchronizesWithDisplayRefreshRate
            ) ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(maximumFramesPerSecond, forKey: .maximumFramesPerSecond)
        try container.encode(synchronizesWithDisplayRefreshRate, forKey: .synchronizesWithDisplayRefreshRate)
    }
}
