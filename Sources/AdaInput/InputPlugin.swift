//
//  InputPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaApp

public struct InputPlugin: Plugin {
    public init() { }

    public func setup(in app: AppWorlds) {
        app.insertResource(Input.shared)
    }
}
