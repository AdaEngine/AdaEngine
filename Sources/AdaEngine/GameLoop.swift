//
//  GameLoop.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

/// The main class responds to update all systems in engine.
/// You can have only one GameLoop per app.
@MainActor
public final class GameLoop {

    public private(set) static var current: GameLoop = GameLoop()

    private var lastUpdate: LongTimeInterval = 0

    private(set) var isIterating = false

    private var isFirstTick: Bool = true

    private var fixedTimestep: FixedTimestep = FixedTimestep(step: 0)

    // MARK: Internal Methods
    public func iterate() async throws {
        if self.isIterating {
            assertionFailure("Can't iterated twice.")
            return
        }

        self.isIterating = true
        defer { self.isIterating = false }

        let now = Time.absolute
        let deltaTime = TimeInterval(max(0, now - self.lastUpdate))
        self.lastUpdate = now

        // that little hack to avoid big delta in the first tick, because delta is equals Time.absolute value.
        if self.isFirstTick {
            self.isFirstTick = false
            return
        }

        let physicsTickPerSecond = Engine.shared.physicsTickPerSecond
        self.fixedTimestep.step = 1 / TimeInterval(physicsTickPerSecond)

        let physicsTime = self.fixedTimestep.advance(with: deltaTime)

        EventManager.default.send(EngineEvents.GameLoopBegan(deltaTime: deltaTime))

        if physicsTime.isFixedTick {
            Input.shared.processEvents()
        }
        
        try RenderEngine.shared.beginFrame()

        try await Application.shared.renderWorld.update(deltaTime)
        await Application.shared.windowManager.update(deltaTime)

        try RenderEngine.shared.endFrame()

        if physicsTime.isFixedTick {
            Input.shared.removeEvents()
        }

        FPSCounter.shared.tick()
    }
}
