//
//  GameLoop.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

/// The main class responds to update all systems in engine.
/// You can have only one GameLoop per app.
final class GameLoop {
    
    private(set) static var current: GameLoop = GameLoop()
    
    private var lastUpdate: TimeInterval = 0
    
    private(set) var isIterating = false
    
    private var isFirstTick: Bool = true
    
    // MARK: Internal Methods
    
    func iterate() throws {
        if self.isIterating {
            assertionFailure("Can't iterated twice.")
            return
        }
        
        self.isIterating = true
        defer { self.isIterating = false }
        
        let now = Time.absolute
        let deltaTime = max(0, now - self.lastUpdate)
        self.lastUpdate = now
        
        // that little hack to avoid big delta in the first tick, because delta is equals Time.absolute value.
        if self.isFirstTick {
            self.isFirstTick = false
            return
        }
        
        EventManager.default.send(EngineEvent.GameLoopBegan(deltaTime: deltaTime))
        
        Input.shared.processEvents()
        
        try RenderEngine.shared.beginFrame()
        
        Application.shared.windowManager.update(deltaTime)
        
        try RenderEngine.shared.endFrame()
        
        Input.shared.removeEvents()
        
        FPSCounter.shader.tick()
    }
}

class FPSCounter {
    
    static let shader = FPSCounter()
    
    private var lastNotificationTime: TimeInterval = 0
    private var notificationDelay: TimeInterval = 1.0
    private var numberOfFrames = 0
    
    func stop() {
        self.lastNotificationTime = 0
        self.numberOfFrames = 0
    }
    
    func tick() {
        if self.lastNotificationTime == 0.0 {
            self.lastNotificationTime = Time.absolute
            return
        }
        
        self.numberOfFrames += 1
        
        let currentTime = Time.absolute
        let elapsedTime = currentTime - self.lastNotificationTime
        
        if elapsedTime >= self.notificationDelay {
            self.notifyUpdateForElapsedTime(elapsedTime)
            self.lastNotificationTime = 0.0
            self.numberOfFrames = 0
        }
    }
    
    private func notifyUpdateForElapsedTime(_ elapsedTime: TimeInterval) {
        let fps = Int(round(Double(self.numberOfFrames) / Double(elapsedTime)))
        EventManager.default.send(EngineEvent.FramesPerSecondEvent(framesPerSecond: fps))
    }
}
