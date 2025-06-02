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
}
