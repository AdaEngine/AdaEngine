//
//  InternalAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

import AdaECS
import AdaUtils
import Math

/// The mode of the window.
public enum WindowMode: UInt64, Sendable {
    /// The windowed mode.
    case windowed

    /// The fullscreen mode.
    case fullscreen
}

/// The title bar background behavior.
public enum WindowTitleBarBackground: Sendable, Equatable {
    /// Use the platform default title bar background.
    case system

    /// Make the title bar background transparent so app content can show through it.
    case transparent
}

/// Platform title bar presentation settings.
public struct WindowTitleBar: Sendable, Equatable {
    /// The title bar background behavior.
    public var background: WindowTitleBarBackground

    /// Whether app content should reserve space for the title bar.
    public var reservesSafeArea: Bool

    /// Height of the top area that starts native window dragging.
    /// If `nil`, the platform title bar height is used when available.
    public var dragRegionHeight: Float?

    /// Offset applied to macOS traffic light buttons. Positive `x` moves right, positive `y` moves down.
    public var trafficLightOffset: Point?

    /// Use the platform default title bar.
    public static let standard = WindowTitleBar(background: .system, reservesSafeArea: true, dragRegionHeight: nil, trafficLightOffset: nil)

    /// Make the title bar background transparent while keeping its safe area reserved.
    public static let transparent = WindowTitleBar(background: .transparent, reservesSafeArea: true, dragRegionHeight: nil, trafficLightOffset: nil)

    /// Make the title bar transparent and let content extend into its safe area.
    public static let overlay = WindowTitleBar(background: .transparent, reservesSafeArea: false, dragRegionHeight: 52, trafficLightOffset: nil)

    public init(
        background: WindowTitleBarBackground,
        reservesSafeArea: Bool = true,
        dragRegionHeight: Float? = nil,
        trafficLightOffset: Point? = nil
    ) {
        self.background = background
        self.reservesSafeArea = reservesSafeArea
        self.dragRegionHeight = dragRegionHeight
        self.trafficLightOffset = trafficLightOffset
    }
}

/// Primary Window parameters.
public struct WindowSettings: Resource {
    /// The minimum size of the window.
    public var minimumSize: Size = Size(width: 800, height: 600)

    /// The mode of the window.
    public var windowMode: WindowMode = .fullscreen

    /// Whether the window is a single window.
    public var isSingleWindow: Bool = false

    /// The title of the window.
    public var title: String?

    /// Platform title bar presentation settings.
    public var titleBar: WindowTitleBar = .standard
}
