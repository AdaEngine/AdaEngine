//
//  AssetsPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaApp

public struct AssetsPlugin: Plugin {
    public init() {}

    public func setup(in app: AppWorlds) {
        do {
            try AssetsManager.initialize(filePath: #filePath)
        } catch {
            print(error)
        }
    }
}
