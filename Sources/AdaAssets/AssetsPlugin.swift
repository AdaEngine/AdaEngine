//
//  AssetsPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaApp
import AdaECS

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
            print(error)
        }
    }
}

@PlainSystem
@inline(__always)
func AssetsProcess(
    _ context: inout WorldUpdateContext
) {
    context.taskGroup.addTask {
        do {
            try await AssetsManager.processResources()
        } catch {
            print("Failed to process")
        }
    }
}
