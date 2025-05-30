//
//  InternalAppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

import AdaECS
import AdaUtils
import Math

public enum WindowMode: UInt64, Sendable {
    case windowed
    case fullscreen
}

/// Primary Window parameters
public struct WindowSettings: Resource {
    public var minimumSize: Size = Size(width: 800, height: 600)
    public var windowMode: WindowMode = .fullscreen
    public var isSingleWindow: Bool = false
    public var title: String?
}

extension EnvironmentValues {
    @Entry public var appWorlds: AppWorlds?

    @Entry var filePath: String?

    @Entry public var windowSettings: WindowSettings = WindowSettings()
}
