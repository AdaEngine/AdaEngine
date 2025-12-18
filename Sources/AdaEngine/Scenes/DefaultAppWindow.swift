//
//  DefaultAppWindow.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.12.2025.
//

import AdaApp

/// Create an empty window scene with attached ``DefaultPlugins``.
public struct DefaultAppWindow: AppScene {
    /// The file path to use for the `AssetsPlugin`.
    let filePath: StaticString

    public var body: some AppScene {
        EmptyWindow()
            .addPlugins(DefaultPlugins(filePath: filePath))
    }

    /// - Parameter filePath: The file path to use for the `AssetsPlugin`.
    public init(filePath: StaticString = #filePath) {
        self.filePath = filePath
    }
}
