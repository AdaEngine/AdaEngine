//
//  GameLoop.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

final class GameLoop {
    
    private(set) static var current: GameLoop = GameLoop()
    
    private var lastUpdate: TimeInterval = 0
    
    private(set) var isIterating = false
    
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
        
        Input.shared.processEvents()
        
        try RenderEngine.shared.beginFrame()
        
        Application.shared.windowManager.update(deltaTime)
        
        try RenderEngine.shared.endFrame()
        
        Input.shared.removeEvents()
    }
}
