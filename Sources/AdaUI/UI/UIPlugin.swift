//
//  UIPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaApp
import AdaECS

public struct UIPlugin: Plugin {

    public init() { }

    public func setup(in app: AppWorlds) {
        app.addSystem(UISystem.self)
    }
}
