//
//  AppBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS
import AdaUtils

/// A protocol that represents a world extractor.
/// Used to extract data from main world to subworlds.
public protocol WorldExctractor {
    /// Extract data from main world to subworld.
    /// - Parameters:
    ///   - mainWorld: The main world.
    ///   - world: The subworld.
    func exctract(from mainWorld: World, to world: World)
}

/// A class that represents a collection of worlds.
@MainActor
public final class AppWorlds {
    /// The main world.
    public var mainWorld: World

    /// The subworlds.
    var subWorlds: [String: AppWorlds]

    /// The world extractor.
    var worldExctractor: (any WorldExctractor)?

    /// The plugins.
    var plugins: [ObjectIdentifier: any Plugin] = [:]

    /// The runner.
    var runner: ((AppWorlds) -> Void)?

    /// The flag that indicates if the app is configured.
    var isConfigured: Bool = false

    var scedulers: [Scheduler]

    /// Initialize a new instance of `AppWorlds` with the given main world and subworlds.
    /// - Parameters:
    ///   - mainWorld: The main world.
    ///   - subWorlds: The subworlds.
    public init(
        mainWorld: World,
        subWorlds: [String : AppWorlds] = [:]
    ) {
        self.mainWorld = mainWorld
        self.subWorlds = subWorlds
        self.scedulers = [Scheduler(name: .update)]
    }
}

public extension AppWorlds {

    /// Set the world extractor.
    /// - Parameter exctractor: The world extractor.
    func setExctractor(_ exctractor: any WorldExctractor) {
        self.worldExctractor = exctractor
    }

    /// Set the world scheduler
    /// - Parameter scheduler: The world scheduler.
    func setSchedulers(_ schedulers: [Scheduler]) {
        self.scedulers = schedulers
    }

    /// Set the runner.
    /// - Parameter block: The runner.
    func setRunner(_ block: @escaping (AppWorlds) -> Void) {
        self.runner = block
    }

    /// Update the app.
    /// - Parameter deltaTime: The delta time.
    func update() async {
        if !isConfigured {
            return
        }

        for sceduler in self.scedulers {
            await sceduler.run(world: mainWorld)

            for world in self.subWorlds.values {
                world.worldExctractor?.exctract(from: mainWorld, to: world.mainWorld)
                await world.update()
            }
        }

        mainWorld.clearTrackers()
    }

    /// Get the subworld builder by name.
    /// - Parameter name: The name of the subworld.
    /// - Returns: The subworld builder.
    func getSubworldBuilder(by name: AppWorldName) -> AppWorlds? {
        self.subWorlds[name.rawValue]
    }

    /// Add a new subworld.
    /// - Parameter subworld: The subworld.
    /// - Parameter name: The name of the subworld.
    func addSubworld(_ subworld: consuming AppWorlds, by name: AppWorldName) {
        self.subWorlds[name.rawValue] = subworld
    }

    /// Add a plugin to the app.
    /// - Parameter plugin: The plugin to add.
    /// - Returns: The app builder.
    @discardableResult
    func addPlugin<T: Plugin>(_ plugin: T) -> Self {
        if self.plugins[ObjectIdentifier(T.self)] != nil {
            fatalError("Plugin already installed")
        }

        self.plugins[ObjectIdentifier(T.self)] = plugin
        plugin.setup(in: self)
        return self
    }

    /// Add a system to the main world.
    /// - Parameters:
    ///   - system: The system to add.
    ///   - scheduler: The scheduler to run the system on.
    /// - Returns: The app builder.
    @discardableResult
    func addSystem<T: System>(
        _ system: T.Type,
        on scheduler: AdaECS.SchedulerName = .update
    ) -> Self {
        self.mainWorld.addSystem(system, on: scheduler)
        return self
    }

    /// Add an entity to the main world.
    /// - Parameter entity: The entity to add.
    /// - Returns: The app builder.
    @discardableResult
    func addEntity(_ entity: Entity) -> Self {
        self.mainWorld.addEntity(entity)
        return self
    }

    /// Insert a resource to the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: The app builder.
    @discardableResult
    func insertResource<T: Resource>(_ resource: consuming T) -> Self {
        self.mainWorld.insertResource(resource)
        return self
    }

    /// Get resource from the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: The app builder.
    func getResource<T: Resource>(_ resource: T.Type) -> T? {
        return self.mainWorld.getResource(resource)
    }

    func build() throws {
        /// Wait until all plugins is loaded
        while !self.plugins.allSatisfy({ $0.value.isLoaded(in: self) }) {
            continue
        }

        self.mainWorld.build()
        try self.subWorlds.values.forEach {
            try $0.build()
        }
        self.isConfigured = true
    }
}


/// A protocol that represents a plugin for the app.
public protocol Plugin: Sendable {
    /// Setup the plugin in the app.
    @MainActor
    func setup(in app: borrowing AppWorlds)

    /// Notify the plugin that the app is ready.
    @MainActor
    func finish(for app: borrowing AppWorlds)

    /// Check if the plugin is loaded. Used for async plugins.
    @MainActor
    func isLoaded(in app: borrowing AppWorlds) -> Bool

    /// Destroy the plugin.
    @MainActor
    func destroy(for app: borrowing AppWorlds)
}

public extension Plugin {
    func isLoaded(in app: borrowing AppWorlds) -> Bool {
        return true
    }

    func finish(for app: borrowing AppWorlds) { }

    @MainActor
    func destroy(for app: borrowing AppWorlds) { }
}

public struct AppWorldName: Hashable, Equatable, RawRepresentable, CustomStringConvertible, Sendable {
    public let rawValue: String
    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let main = AppWorldName(rawValue: "Main")
}
