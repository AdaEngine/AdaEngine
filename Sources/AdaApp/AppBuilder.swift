//
//  AppBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS
import AdaUtils

@MainActor
public class AppWorlds {
    public var mainWorld: World
    var subWorlds: [String: AppWorlds]

    var plugins: [ObjectIdentifier: any Plugin] = [:]
    var runner: ((AppWorlds) -> Void)?

    var isConfigured: Bool = false

    init(mainWorld: World, subWorlds: [String : AppWorlds]) {
        self.mainWorld = mainWorld
        self.subWorlds = subWorlds
    }
}

public extension AppWorlds {

    func update(_ deltaTime: AdaUtils.TimeInterval) async {
        if !isConfigured {
            return
        }

        await mainWorld.update(deltaTime)

        for world in self.subWorlds.values {
            await world.update(deltaTime)
        }
    }

    func setRunner(_ block: @escaping (AppWorlds) -> Void) {
        self.runner = block
    }

    func getSubworldBuilder(by name: String) -> AppWorlds? {
        self.subWorlds[name]
    }

    func getSubworldBuilder<L: Label>(by label: L.Type) -> AppWorlds? {
        self.subWorlds[label.name]
    }

    @discardableResult
    func addPlugin<T: Plugin>(_ plugin: T) -> Self {
        if self.plugins[ObjectIdentifier(T.self)] != nil {
            fatalError("Plugin already installed")
        }

        self.plugins[ObjectIdentifier(T.self)] = plugin
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

    func getResource<T: Resource>(_ resource: T.Type) -> T? {
        return self.mainWorld.getResource(resource)
    }

    func build() throws {
        /// Wait until all plugins is loaded
        while !self.plugins.allSatisfy({ $0.value.isLoaded() }) {
            continue
        }

        self.mainWorld.build()
        try self.subWorlds.values.forEach {
            try $0.build()
        }
        self.isConfigured = true
    }
}


public protocol Plugin: Sendable {
    @MainActor
    func setup(in app: AppWorlds)

    @MainActor
    func isLoaded() -> Bool

    @MainActor
    func finish()
}

public extension Plugin {
    func isLoaded() -> Bool {
        return true
    }

    func finish() { }
}

public protocol Label {
    static var name: String { get }
}

public extension Label {
    static var name: String { String(reflecting: Self.self) }
}
