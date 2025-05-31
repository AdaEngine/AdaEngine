//
//  AppBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS
import AdaUtils

public protocol WorldExctractor {
    func exctract(from mainWorld: World, to world: World)
}

@MainActor
public class AppWorlds {
    public var mainWorld: World
    var subWorlds: [String: AppWorlds]
    
    var worldExctractor: (any WorldExctractor)?

    var plugins: [ObjectIdentifier: any Plugin] = [:]
    var runner: ((AppWorlds) -> Void)?

    var isConfigured: Bool = false

    init(
        mainWorld: World,
        subWorlds: [String : AppWorlds] = [:]
    ) {
        self.mainWorld = mainWorld
        self.subWorlds = subWorlds
    }
}

public extension AppWorlds {

    func setExctractor(_ exctractor: any WorldExctractor) {
        self.worldExctractor = exctractor
    }

    func setRunner(_ block: @escaping (AppWorlds) -> Void) {
        self.runner = block
    }

    func update(_ deltaTime: AdaUtils.TimeInterval) async {
        if !isConfigured {
            return
        }

        await mainWorld.update(deltaTime)

        for world in self.subWorlds.values {
            world.worldExctractor?.exctract(from: mainWorld, to: world.mainWorld)
            await world.update(deltaTime)
        }
    }

    func getSubworldBuilder(by name: AppWorldName) -> AppWorlds? {
        self.subWorlds[name.rawValue]
    }

    func createSubworld(by name: AppWorldName) -> AppWorlds {
        let subworld = AppWorlds(mainWorld: World(name: name.rawValue))
        self.subWorlds[name.rawValue] = subworld
        return subworld
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
    func addSystem<T: System>(_ system: T.Type, scheduler: Scheduler = .update) -> Self {
        self.mainWorld.addSystem(system, on: scheduler)
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
    func finish()

    @MainActor
    func isLoaded() -> Bool

    @MainActor
    func destroy()
}

public extension Plugin {
    func isLoaded() -> Bool {
        return true
    }

    func finish() { }

    @MainActor
    func destroy() { }
}

public struct AppWorldName: Hashable, Equatable, RawRepresentable, CustomStringConvertible, Sendable {
    public let rawValue: String
    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let main = Scheduler(rawValue: "Main")
}
