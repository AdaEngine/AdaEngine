//
//  InputPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS
import AdaApp

public struct InputPlugin: Plugin {
    public init() { }

    public func setup(in app: AppWorlds) {
        app.insertResource(Input.shared)
        app.addSystem(InputPostUpdateSystem.self, on: .postUpdate)
    }
}

@PlainSystem
func InputPostUpdate(
    _ input: ResQuery<Input>
) {
    Task {
        await input.wrappedValue?.removeEvents()
    }
}
