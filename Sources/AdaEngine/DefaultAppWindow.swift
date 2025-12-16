//
//  DefaultAppWindow.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.12.2025.
//

import AdaApp

/// Create an empty window with attached ``DefaultPlugins``.
public struct DefaultAppWindow: AppScene {

    let filePath: StaticString

    public var body: some AppScene {
        EmptyWindow()
            .addPlugins(DefaultPlugins(filePath: filePath))
    }

    public init(filePath: StaticString = #filePath) {
        self.filePath = filePath
    }
}
