//
//  AssetsPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaApp
import AdaECS
import Logging

public struct AssetsPlugin: Plugin {

    private let filePath: StaticString

    public init(filePath: StaticString = #filePath) {
        self.filePath = filePath
    }

    public func setup(in app: AppWorlds) {
        do {
            try AssetsManager.initialize(filePath: filePath)
            app.addSystem(AssetsProcessSystem.self, on: .preUpdate)
        } catch {
            Logger(label: "org.adaengine.AssetsPlugin").error("Setup failed with error: \(error)")
        }
    }
}

@System
@inline(__always)
func AssetsProcess() {
    Task {
        do {
            try await AssetsManager.processResources()
        } catch {
            Logger(label: "org.adaengine.AssetsPlugin").error("Assets processing failed with error: \(error)")
        }
    }
}
