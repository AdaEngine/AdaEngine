//
//  WindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/29/22.
//

/// Base protocol describes platform specific window.
public protocol SystemWindow {
    /// Window title.
    var title: String { get set }
    
    /// Window size.
    var size: Size { get set }
    
    /// Window position on screen.
    var position: Point { get set }
}

/// Base class using to manage windows in application. All created window should be registred there.
/// Application has only one window manager per instance.
@MainActor
open class UIWindowManager {

    /// Returns all windows registred in current process.
    public internal(set) var windows: [UIWindow] = []
    
    /// Contains active window if available.
    public private(set) var activeWindow: UIWindow?

    public nonisolated init() { }

    /// Called each frame to update windows.
    func update(_ deltaTime: TimeInterval) async {
        for window in self.windows {
            let menuBuilder = self.menuBuilder(for: window)
            menuBuilder?.updateIfNeeded()

            for event in Input.shared.eventsPool where event.window == window.id {
                window.sendEvent(event)
            }
            
            await window.internalUpdate(deltaTime)

            if window.canDraw {
                var context = UIGraphicsContext(window: window)
                context.beginDraw(in: window.frame.size, scaleFactor: 1)
                window.draw(with: context)
                context.commitDraw()
            }
        }
    }

    open func menuBuilder(for window: UIWindow) -> UIMenuBuilder? {
        return nil
    }

    /// Create platform window and register app window inside the manager.
    /// - Warning: You should call this method when override this method!
    open func createWindow(for window: UIWindow) {
        self.windows.append(window)
        window.windowDidReady()
    }
    
    /// Show window and make it focused.
    open func showWindow(_ window: UIWindow, isFocused: Bool) {
        fatalErrorMethodNotImplemented()
    }
    
    /// Close window.
    open func closeWindow(_ window: UIWindow) {
        fatalErrorMethodNotImplemented()
    }
    
    /// Set window mode for window.
    open func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {
        fatalErrorMethodNotImplemented()
    }
    
    /// Set minimum size for window.
    open func setMinimumSize(_ size: Size, for window: UIWindow) {
        fatalErrorMethodNotImplemented()
    }
    
    /// Resize window.
    open func resizeWindow(_ window: UIWindow, size: Size) {
        fatalErrorMethodNotImplemented()
    }
    
    /// Get screen instance for window.
    open func getScreen(for window: UIWindow) -> Screen? {
        fatalErrorMethodNotImplemented()
    }
    
    internal func setActiveWindow(_ window: UIWindow) {
        self.activeWindow?.isActive = false
        
        self.activeWindow?.windowDidResignActive()
        
        self.activeWindow = window
        window.isActive = true
        window.windowDidBecameActive()
    }
    
    internal func setCursorShape(_ shape: Input.CursorShape) {
        fatalErrorMethodNotImplemented()
    }
    
    internal func getCursorShape() -> Input.CursorShape {
        fatalErrorMethodNotImplemented()
    }
    
    internal func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotspot: Vector2) {
        fatalErrorMethodNotImplemented()
    }
    
    internal func setMouseMode(_ mode: Input.MouseMode) {
        fatalErrorMethodNotImplemented()
    }
    
    internal func getMouseMode() -> Input.MouseMode {
        fatalErrorMethodNotImplemented()
    }
    
    internal func updateCursor() {
        fatalErrorMethodNotImplemented()
    }
    
    public final func removeWindow(_ window: UIWindow, setActiveAnotherIfNeeded: Bool = true) {
        guard let index = self.windows.firstIndex(where: { $0 === window }) else {
            assertionFailure("We don't have window in windows stack. That strange problem.")
            return
        }
        
        // Destory window from render window
        try? RenderEngine.shared.destroyWindow(window.id)
        
        self.windows.remove(at: index)
        window.windowDidDisappear()
        
        // Check if we don't have any windows we should shutdown and quit engine process
        guard !self.windows.isEmpty else {
            Application.shared.terminate()
            return
        }
        
        if setActiveAnotherIfNeeded {
            // Set last window as active
            // TODO: (Vlad) I think we should have any order
            let newUIWindow = self.windows.last!
            self.setActiveWindow(newUIWindow)
        }
    }
}
