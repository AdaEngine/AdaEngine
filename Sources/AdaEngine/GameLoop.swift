//
//  GameLoop.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

final class GameLoop {
    
    static var current: GameLoop = GameLoop()
    
    private var lastUpdate: TimeInterval = 0
    
    func iterate() {
        let now = Time.absolute
        let deltaTime = max(0, now - self.lastUpdate)
        self.lastUpdate = now
        
        // FIXME: Think about it later
        Time.deltaTime = deltaTime
        
        SceneManager.shared.update(deltaTime)
        
        do {
            try RenderEngine.shared.draw()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
