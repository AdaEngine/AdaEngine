@_spi(Scripting) import AdaECS
import AdaUtils
import Foundation
import Gravity

/// An isolated ECS world for one Ada Script test (ADR-0024), created by `TestWorld()`.
///
/// It owns a fresh `World` with the module's systems installed through the normal plugin path, so a system
/// that works here keeps the same scheduler, access checks and deferred commands it has in a game. Time moves
/// only when the test calls `run` or `advance`.
@GSExportable("AdaTestWorld")
final class AdaScriptTestWorld: @unchecked Sendable, AdaScriptNonSendableBridge {
    private static let tickDuration: Float = 1.0 / 60.0

    @GSExportableIgnore
    private let world: World

    @GSExportableIgnore
    private let exclusive: AnnotatedGravityExclusiveAccess

    @GSExportableIgnore
    private let virtualMachine: GravityVirtualMachine

    @GSExportableIgnore
    private let reportDiagnostic: @Sendable (String) -> Void

    @GSExportableIgnore
    private let installer: @Sendable (String?, Set<String>) -> Set<String>

    @GSExportableIgnore
    private var installedSystems = Set<String>()

    @GSExportableIgnore
    private let startupSystems: Set<String>

    @GSExportableIgnore
    private var didStart = false

    @GSExportableIgnore
    static func make(
        world: World,
        exclusive: AnnotatedGravityExclusiveAccess,
        virtualMachine: GravityVirtualMachine,
        installer: @escaping @Sendable (String?, Set<String>) -> Set<String>,
        startupSystems: Set<String>,
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) -> AdaScriptTestWorld {
        AdaScriptTestWorld(
            world: world,
            exclusive: exclusive,
            virtualMachine: virtualMachine,
            installer: installer,
            startupSystems: startupSystems,
            reportDiagnostic: reportDiagnostic
        )
    }

    private init(
        world: World,
        exclusive: AnnotatedGravityExclusiveAccess,
        virtualMachine: GravityVirtualMachine,
        installer: @escaping @Sendable (String?, Set<String>) -> Set<String>,
        startupSystems: Set<String>,
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) {
        self.world = world
        self.exclusive = exclusive
        self.installer = installer
        self.startupSystems = startupSystems
        self.virtualMachine = virtualMachine
        self.reportDiagnostic = reportDiagnostic
    }

    // MARK: Entities

    /// Spawns an entity from a list of component values and returns its id, or -1.
    func spawn(_ components: GSValue) -> Int {
        exclusive.spawn(components)
    }

    func insert(_ entity: Int, _ component: GSValue) -> Bool {
        exclusive.insert(entity, component)
    }

    func remove(_ entity: Int, _ component: String) -> Bool {
        exclusive.remove(entity, component)
    }

    func despawn(_ entity: Int) -> Bool {
        exclusive.despawn(entity)
    }

    func has(_ entity: Int, _ component: String) -> Bool {
        guard let resolved = resolve(component) else {
            return false
        }
        return world.has(resolved.identifier, in: entity)
    }

    /// Reads one field of a component, or null when the entity does not have it.
    func read(_ entity: Int, _ component: String, _ field: String) -> GSValue {
        let null = GSValue(nullIn: virtualMachine)
        guard let resolved = resolve(component) else {
            return null
        }
        guard let reflected = resolved.fields.first(where: { $0.key == field }) else {
            reportDiagnostic("Component '\(component)' has no field '\(field)'")
            return null
        }
        guard let value = world.readComponentField(component: resolved.identifier, entity: entity, field: reflected) else {
            return null
        }
        return AnnotatedGravityValueBridge.makeGravityValue(value, virtualMachine: virtualMachine)
    }

    /// The number of entities that currently have the component.
    func count(_ component: String) -> Int {
        guard let resolved = resolve(component) else {
            return 0
        }
        return world.getEntities().filter { world.has(resolved.identifier, in: $0.id) }.count
    }

    // MARK: Time

    /// Installs every system of the module, then runs the world for a number of fixed 1/60 s ticks.
    func run(_ ticks: Int) {
        install(nil)
        tick(ticks)
    }

    /// Installs only `system` (its class or its name), then runs the world for a number of fixed 1/60 s ticks.
    /// Systems installed by earlier calls keep running.
    func runSystem(_ system: GSValue, _ ticks: Int) {
        let name = system.isString ? system.toString : system.isClass ? system.name : nil
        guard let name else {
            reportDiagnostic("TestWorld.runSystem expects a system class or its name")
            return
        }
        install(name)
        tick(ticks)
    }

    /// Installs every system, then runs the world once with a step of `seconds`.
    func advance(_ seconds: Double) {
        install(nil)
        step(Float(max(seconds, 0)))
    }

    // MARK: Internals

    @GSExportableIgnore
    private func install(_ className: String?) {
        installedSystems.formUnion(installer(className, installedSystems))
    }

    @GSExportableIgnore
    private func tick(_ ticks: Int) {
        for _ in 0..<max(ticks, 0) {
            step(Self.tickDuration)
        }
    }

    @GSExportableIgnore
    private func step(_ deltaTime: Float) {
        // The startup scheduler exists only once a startup system is installed, and runs on the first step only.
        if !didStart, !installedSystems.isDisjoint(with: startupSystems) {
            didStart = true
            runScheduler(.startup, deltaTime: deltaTime)
        }
        runScheduler(.update, deltaTime: deltaTime)
    }

    /// Blocks the test until the scheduler finishes. A test is a synchronous script call, and the scheduler is
    /// async, so the wait is the bridge between them. The VM lock is released meanwhile because the scheduler's
    /// worker threads take it to run script systems, and the test thread does nothing until they are done.
    @GSExportableIgnore
    private func runScheduler(_ name: SchedulerName, deltaTime: Float) {
        let finished = DispatchSemaphore(value: 0)
        let world = self.world
        AdaScriptRuntimeCoordinator.lock.unlock()
        Task {
            await world.runScheduler(name, deltaTime: deltaTime)
            finished.signal()
        }
        finished.wait()
        AdaScriptRuntimeCoordinator.lock.lock()
    }

    @GSExportableIgnore
    private func resolve(_ component: String) -> ResolvedAnnotatedComponent? {
        guard let resolved = AdaScriptPlugin.resolveComponent(named: component, world: world) else {
            reportDiagnostic("Unknown component '\(component)'")
            return nil
        }
        return resolved
    }
}

/// Creates a `TestWorld` for the script. The plugin supplies `build`, because only it can install the module
/// into a fresh world.
@GSExportable("AdaTestWorldFactory")
final class AdaScriptTestWorldFactory: @unchecked Sendable {
    @GSExportableIgnore
    var build: (@Sendable () -> AdaScriptTestWorld?)?

    func make() -> AdaScriptTestWorld? {
        build?()
    }
}
