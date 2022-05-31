//
//  MacOSWindowManager.swift
//  
//
//  Created by v.prusakov on 5/29/22.
//

#if MACOS
import AppKit

final class MacOSWindowManager: WindowManager {
    
    private lazy var nsWindowDelegate = NSWindowDelegateObject(windowManager: self)
    
    override func createWindow(for window: Window) {
        let frame = window.frame
        
        let contentRect = CGRect(
            x: CGFloat(frame.origin.x),
            y: CGFloat(frame.origin.y),
            width: CGFloat(frame.size.width),
            height: CGFloat(frame.size.height)
        )
        
        /// Register view in engine
        let metalView = MetalView(frame: contentRect)
        try? RenderEngine.shared.createWindow(window.id, for: metalView, size: frame.size)
        
        let systemWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false,
            screen: NSScreen.main
        )
        
        let minSize = CGSize(width: 800, height: 600)
        
        systemWindow.contentMinSize = minSize
        systemWindow.minSize = minSize
        systemWindow.contentView = metalView
        systemWindow.collectionBehavior = [.fullScreenPrimary]
        systemWindow.center()
        systemWindow.delegate = nsWindowDelegate
        
        window.systemWindow = systemWindow
        
        super.createWindow(for: window)
    }
    
    override func showWindow(_ window: Window, isFocused: Bool) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }
        
        if isFocused {
            nsWindow.makeKeyAndOrderFront(nil)
        } else {
            nsWindow.orderFront(nil)
        }
        
        window.windowDidAppear()
        
        self.setActiveWindow(window)
    }
    
    override func setWindowMode(_ window: Window, mode: Window.Mode) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }
        
        let isFullScreen = nsWindow.styleMask.contains(.fullScreen)
        let shouldToggleFullScreen = isFullScreen != (mode == .fullscreen)
        
        if shouldToggleFullScreen {
            nsWindow.toggleFullScreen(nil)
        }
    }
    
    override func closeWindow(_ window: Window) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }

        self.removeWindow(window, setActiveAnotherIfNeeded: true)
        
        nsWindow.close()
    }
    
    func findWindow(for nsWindow: NSWindow) -> Window? {
        return self.windows.first {
            ($0.systemWindow as? NSWindow) === nsWindow
        }
    }
}

// MARK: - NSWindowDelegate

final class NSWindowDelegateObject: NSObject, NSWindowDelegate {
    
    unowned let windowManager: MacOSWindowManager
    
    init(windowManager: MacOSWindowManager) {
        self.windowManager = windowManager
    }
    
    // MARK: NSWindowDelegate impl
    
    func windowWillClose(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }
        
        self.windowManager.removeWindow(window)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }
        
        self.windowManager.setActiveWindow(window)
    }
    
    func windowDidResize(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }
        
        let size = nsWindow.size
        window.frame = Rect(origin: nsWindow.position, size: size)
        try? RenderEngine.shared.renderBackend.resizeWindow(window.id, newSize: size)
    }
    
    func windowDidMove(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }
        
        window.frame.origin = nsWindow.position
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }
        
        window.isFullscreen = false
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }
        
        window.isFullscreen = true
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard
            let window = self.windowManager.findWindow(for: sender)
        else {
            return
        }
        
        return window.windowShouldClose()
    }
}

// MARK: - NSWindow + SystemWindow

extension NSWindow: SystemWindow {
    public var position: Point {
        get {
            return self.frame.origin.toEnginePoint
        }
        set {
            self.setFrameOrigin(NSPoint(x: CGFloat(newValue.x), y: CGFloat(newValue.y)))
        }
    }
    
    public var size: Size {
        get {
            return self.frame.size.toEngineSize
        }
        set {
            self.setContentSize(NSSize(width: CGFloat(newValue.width), height: CGFloat(newValue.height)))
        }
    }
}

extension CGRect {
    var toEngineRect: Rect {
        return Rect(origin: self.origin.toEnginePoint, size: self.size.toEngineSize)
    }
}

extension CGPoint {
    var toEnginePoint: Point {
        return Point(x: Float(self.x), y: Float(self.y))
    }
}

extension CGSize {
    var toEngineSize: Size {
        return Size(width: Float(self.width), height: Float(self.height))
    }
}

#endif
