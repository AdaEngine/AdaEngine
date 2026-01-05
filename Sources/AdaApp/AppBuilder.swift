//
//  AppBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaECS
import AdaUtils
import Logging

// TODO: Do we need be a Main Actor???

/// A protocol that represents a world extractor.
/// Used to extract data from main world to subworlds.
public protocol WorldExctractor {
    /// Extract data from main world to subworld.
    /// - Parameters:
    ///   - mainWorld: The main world.
    ///   - world: The subworld.
    func exctract(from mainWorld: World, to world: World) async
}

/// A class that represents a collection of worlds.
@MainActor
public final class AppWorlds {

    public typealias ApplicationRunnerBlock = () -> Void

    /// The main world.
    public var main: World

    /// The subworlds.
    var subWorlds: [String: AppWorlds]

    /// The world extractor.
    nonisolated(unsafe) var worldExctractor: (any WorldExctractor)?

    /// The plugins.
    @usableFromInline
    var plugins: ContiguousArray<any Plugin> = []

    /// Names of installed plugins.
    @usableFromInline
    var installedPlugins: [ObjectIdentifier: String] = [:]

    private var pluginDepth = 0

    /// The runner.
    var runner: ApplicationRunnerBlock?

    /// The flag that indicates if the app is configured.
    var isConfigured: Bool = false

    /// Default scheduler that will run first in ``update()`` method
    public var updateScheduler: SchedulerName?

    let logger: Logger

    /// Initialize a new instance of `AppWorlds` with the given main world and subworlds.
    /// - Parameters:
    ///   - mainWorld: The main world.
    ///   - subWorlds: The subworlds.
    public init(
        main: World,
        subWorlds: [String : AppWorlds] = [:]
    ) {
        self.main = main
        self.subWorlds = subWorlds
        self.logger = Logger(label: "org.adaengine.AdaApp.\(main.name ?? "UnknownWorld")")
    }
}

public extension AppWorlds {

    /// Set the world extractor.
    /// - Parameter exctractor: The world extractor.
    func setExctractor(_ exctractor: any WorldExctractor) {
        unsafe self.worldExctractor = exctractor
    }

    /// Set the runner.
    /// - Parameter block: The runner.
    func setRunner(_ block: @escaping ApplicationRunnerBlock) {
        self.runner = block
    }

    /// Update the app.
    /// - Parameter deltaTime: The delta time.
    func update() async throws {
        guard isConfigured else {
            return
        }
        guard let updateScheduler else {
            assertionFailure("Update scheduler is empty")
            return
        }

        await main.runScheduler(updateScheduler)

        for world in self.subWorlds.values {
            unsafe await world.worldExctractor?.exctract(from: main, to: world.main)
            try await world.update()
        }
        
        main.clearTrackers()
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
    @inlinable
    @discardableResult
    func addPlugin<T: Plugin>(_ plugin: T) -> Self {
        if let pluginName = self.installedPlugins[ObjectIdentifier(T.self)] {
            assertionFailure("Plugin \(pluginName) already installed")
            return self
        }

        self.plugins.append(plugin)
        return self
    }

    /// Insert plugin to specific index.
    @inlinable
    @discardableResult
    func insertPlugin<T: Plugin, C: Plugin>(_ plugin: T, after pluginType: C.Type) -> Self {
        if let pluginName = self.installedPlugins[ObjectIdentifier(T.self)] {
            assertionFailure("Plugin \(pluginName) already installed")
            return self
        }

        guard let findPluginIndex = self.plugins.firstIndex(where: { type(of: $0) == pluginType }) else {
            assertionFailure("Can't find plugin with type \(pluginType)")
            return self
        }
        self.plugins.insert(plugin, at: findPluginIndex + 1)
        return self
    }

    /// Setup plugins.
    func build() async throws {
        await self.setupPlugins(self.plugins[...])
        assert(self.pluginDepth == 0, "Plugins installed recursevly")

        for subWorld in self.subWorlds.values {
            try await subWorld.build()
        }

        /// Wait until all plugins is loaded
        while !self.plugins.allSatisfy({ $0.isLoaded(in: self) }) {
            await Task.yield()
        }
    
        self.plugins.forEach { $0.finish(for: self) }
        self.isConfigured = true
    }
}

private extension AppWorlds {
    private func setupPlugins(_ plugins: ContiguousArray<any Plugin>.SubSequence) async {
        var index = plugins.endIndex
        for plugin in plugins {
            self.pluginDepth += 1

            if let pluginName = self.installedPlugins[ObjectIdentifier(type(of: plugin))] {
                assertionFailure("Plugin \(pluginName) already setuped")
            }

            plugin.setup(in: self)

            while !plugin.isLoaded(in: self) {
                await Task.yield()
            }

            self.logger.debug("Plugin installed \(type(of: plugin))")

            /// If plugin add a new plugins, we should check it.
            if !self.plugins[index...].isEmpty {
                await setupPlugins(self.plugins[index...])
                index = self.plugins.endIndex
            }

            self.pluginDepth -= 1

            self.installedPlugins[ObjectIdentifier(type(of: plugin))] = String(reflecting: type(of: plugin))
        }
    }
}

// MARK: - World Proxy

public extension AppWorlds {
    /// Add a system to the main world.
    /// - Parameters:
    ///   - system: The system to add.
    ///   - scheduler: The scheduler to run the system on.
    /// - Returns: The app builder.
    @inlinable
    @discardableResult
    func addSystem<T: System>(
        _ system: T.Type,
        on scheduler: AdaECS.SchedulerName = .update
    ) -> Self {
        self.main.addSystem(system, on: scheduler)
        return self
    }

    @inlinable
    @discardableResult
    func spawn(
        _ name: String = "",
        @ComponentsBuilder components: () -> ComponentsBundle
    ) -> Entity {
        return self.main.spawn(name, components: components)
    }

    @inlinable
    @discardableResult
    func spawn<T: ComponentsBundle>(
        _ name: String = "",
        bundle: consuming T
    ) -> Entity {
        return self.main.spawn(name, bundle: bundle)
    }

    @inlinable
    @discardableResult
    func spawn(_ name: String = "") -> Entity {
        return main.spawn(name)
    }

    /// Insert a resource to the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: The app builder.
    @inlinable
    @discardableResult
    func insertResource<T: Resource>(_ resource: consuming T) -> Self {
        self.main.insertResource(resource)
        return self
    }

    /// Create a resource from world.
    /// - Parameter type: The resource type.
    /// - Returns: A resource instance.
    @inlinable
    @discardableResult
    func createResource<T: Resource & WorldInitable>(_ type: T.Type) -> T {
        return self.main.createResource(of: type)
    }

    /// Create a resource from world.
    /// - Parameter type: The resource type.
    /// - Returns: A resource instance.
    @inlinable
    @discardableResult
    func initResource<T: Resource & WorldInitable>(_ type: T.Type) -> Self {
        _ = self.main.createResource(of: type)
        return self
    }

    /// Create a resource from world.
    /// - Parameter type: The resource type.
    /// - Returns: A resource instance.
    @inlinable
    @discardableResult
    func initResource<T: Resource & DefaultValue>(_ type: T.Type) -> Self {
        _ = self.main.insertResource(T.defaultValue)
        return self
    }

    /// Get resource from the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: The app builder.
    @inlinable
    func getResource<T: Resource>(_ resource: T.Type) -> T? {
        return self.main.getResource(resource)
    }

    /// Get mutable resource from the world.
    /// - Parameter resource: The resource to insert.
    /// - Returns: The app builder.
    @inlinable
    func getRefResource<T: Resource>(_ resource: T.Type) -> Ref<T> {
        self.main.getRefResource(resource)
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
