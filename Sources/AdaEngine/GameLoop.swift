//
//  GameLoop.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

final class GameLoop {
    
    private(set) static var current: GameLoop = GameLoop()
    
    private var lastUpdate: TimeInterval = 0
    
    public private(set) var isIterating = false
    
    // MARK: Internal Methods
    
    func iterate() throws {
        if self.isIterating {
            assertionFailure("Can't iterated twice.")
            return
        }
        
        self.isIterating = true
        
        let now = Time.absolute
        let deltaTime = max(0, now - self.lastUpdate)
        self.lastUpdate = now
        
        // FIXME: Think about it later
        Time.deltaTime = deltaTime
        
        Input.shared.processEvents()
        
        try RenderEngine.shared.beginFrame()
        
        Application.shared.windowManager.update(deltaTime)
        
        try RenderEngine.shared.endFrame()
        
        Input.shared.removeEvents()
        
        self.isIterating = false
    }
}
