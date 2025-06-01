//
//  MainLoop.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

import AdaApp
import AdaUtils
@_spi(AdaEngine) import AdaAssets
import AdaRender
@_spi(Internal) import AdaUI
@_spi(Internal) import AdaInput

/// The main class responds to update all systems in engine.
/// You can have only one MainLoop per app.
@MainActor
public final class MainLoop {

    public private(set) static var current: MainLoop = MainLoop()

    private var lastUpdate: LongTimeInterval = 0

    private(set) var isIterating = false

    private var isFirstTick: Bool = true

    private var fixedTimestep: FixedTimestep = FixedTimestep(step: 0)

    public func setup() {
        let physicsTickPerSecond = Engine.shared.physicsTickPerSecond
        self.fixedTimestep.step = 1 / TimeInterval(physicsTickPerSecond)
    }
    
    public func iterate(_ appWorlds: AppWorlds) async throws {
        if self.isIterating {
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

        EventManager.default.send(EngineEvents.MainLoopBegan(deltaTime: deltaTime))
        try await AssetsManager.processResources()

        try RenderEngine.shared.beginFrame()
        await Application.shared.windowManager.update(deltaTime)
        await appWorlds.update()
        try RenderEngine.shared.endFrame()
        Input.shared.removeEvents()
    }
}
