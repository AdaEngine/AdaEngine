//
//  AppBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS

public class AppWorlds: @unchecked Sendable {
    public var mainWorld: World
    var subWorlds: [String: AppWorlds]

    var plugins: [any Plugin] = []

    init(mainWorld: World, subWorlds: [String : AppWorlds]) {
        self.mainWorld = mainWorld
        self.subWorlds = subWorlds
    }
}

public extension AppWorlds {

    func getSubworldBuilder(by name: String) -> AppWorlds? {
        self.subWorlds[name]
    }

    @discardableResult
    func addPlugin<T: Plugin>(_ plugin: T) -> Self {
        plugin.setup(in: self)
        return self
    }

    @discardableResult
    func addSystem<T: System>(_ system: T.Type) -> Self {
        self.mainWorld.addSystem(system)
        return self
    }

    @discardableResult
    func insertResource<T: Resource>(_ resource: T) -> Self {
        self.mainWorld.insertResource(resource)
        return self
    }

    func build() throws {
        self.mainWorld.build()
        try self.subWorlds.values.forEach {
            try $0.build()
        }
    }
}

public protocol Plugin: Sendable {
    func setup(in app: AppWorlds)

    func finish()
}

public extension Plugin {
    func finish() { }
}
