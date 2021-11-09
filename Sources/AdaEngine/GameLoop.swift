//
//  GameLoop.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

final class GameLoop {
    
    private(set) static var current: GameLoop!
    
    private var lastUpdate: TimeInterval = 0
    
    // MARK: Internal Methods
    
    func iterate() {
        let now = Time.absolute
        let deltaTime = max(0, now - self.lastUpdate)
        self.lastUpdate = now
        
        // FIXME: Think about it later
        Time.deltaTime = deltaTime
        
        Input.shared.processEvents()
        
        SceneManager.shared.update(deltaTime)
        
        do {
            try RenderEngine.shared.draw()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func makeCurrent() {
        GameLoop.current = self
    }
}
