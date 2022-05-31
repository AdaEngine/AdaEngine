//
//  WindowManager.swift
//  
//
//  Created by v.prusakov on 5/29/22.
//

open class WindowManager {
    
    public internal(set) var windows: [Window] = []
    
    public private(set) var activeWindow: Window?
    
    internal init() { }
    
    func update(_ deltaTime: TimeInterval) {
        for window in self.windows {
            
            for event in Input.shared.eventsPool {
                window.sendEvent(event)
            }
            
            window.sceneManager.update(deltaTime)
            
            if window.shouldDraw {
                let context = GUIRenderContext(window: window.id)
                
                context.beginDraw(in: window.frame)
                
                window.draw(with: context)
                
                context.commitDraw()
            }
        }
    }
    
    open func createWindow(for window: Window) {
        self.windows.append(window)
    }
    
    open func showWindow(_ window: Window, isFocused: Bool) {
        fatalErrorMethodNotImplemented()
    }
    
    open func closeWindow(_ window: Window) {
        fatalErrorMethodNotImplemented()
    }
    
    internal func setActiveWindow(_ window: Window) {
        self.activeWindow?.isActive = false
        
        self.activeWindow = window
        window.isActive = true
    }
    
    func removeWindow(_ window: Window, setActiveAnotherIfNeeded: Bool = true) {
        guard let index = self.windows.firstIndex(where: { $0 === window }) else {
            assertionFailure("We don't have window in windows stack. That strange problem.")
            return
        }
        
        // Destory window from render window
        try? RenderEngine.shared.renderBackend.destroyWindow(window.id)
        
        self.windows.remove(at: index)
        window.windowDidDisappear()
        
        // Check if we don't have any windows we should shutdown and quit engine process
        guard !self.windows.isEmpty else {
            Application.shared.terminate()
            return
        }
        
        if setActiveAnotherIfNeeded {
            // Set last window as active
            // TODO: I think we should have any order
            let newWindow = self.windows.last!
            self.setActiveWindow(newWindow)
        }
    }
}

public protocol SystemWindow {
    var title: String { get set }
    
    var size: Size { get set }
    
    var position: Point { get set }
}
