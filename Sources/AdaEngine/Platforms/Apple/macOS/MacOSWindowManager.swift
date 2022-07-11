//
//  MacOSWindowManager.swift
//  
//
//  Created by v.prusakov on 5/29/22.
//

#if os(macOS)
import AppKit

final class MacOSWindowManager: WindowManager {
    
    private lazy var nsWindowDelegate = NSWindowDelegateObject(windowManager: self)
    
    override func createWindow(for window: Window) {
        
        let minSize = Window.defaultMinimumSize
        
        let frame = window.frame
        let size = frame.size == .zero ? minSize : frame.size
        
        let contentRect = CGRect(
            x: CGFloat(frame.origin.x),
            y: CGFloat(frame.origin.y),
            width: CGFloat(size.width),
            height: CGFloat(size.height)
        )
        
        /// Register view in engine
        let metalView = MetalView(windowId: window.id, frame: contentRect)
        
        try? RenderEngine.shared.createWindow(window.id, for: metalView, size: size)
        
        let systemWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false,
            screen: NSScreen.main
        )
        
        systemWindow.contentView = metalView
        systemWindow.collectionBehavior = [.fullScreenPrimary]
        systemWindow.center()
        systemWindow.delegate = nsWindowDelegate
        systemWindow.backgroundColor = .black
        
        window.systemWindow = systemWindow
        window.minSize = minSize
        
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
    
    override func resizeWindow(_ window: Window, size: Size) {
        let nsWindow = window.systemWindow as? NSWindow

        let cgSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
        nsWindow?.setContentSize(cgSize)
    }
    
    override func setMinimumSize(_ size: Size, for window: Window) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }

        let minSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
        
        nsWindow.contentMinSize = minSize
        nsWindow.minSize = minSize
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
        
        if window.frame.size != nsWindow.size {
            window.frame = Rect(origin: .zero, size: size)
        }
        
        try? RenderEngine.shared.renderBackend.resizeWindow(window.id, newSize: size)
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
            return true
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
            // we always should contain content view
            return self.contentView!.frame.size.toEngineSize
        }
        set {
            self.setContentSize(NSSize(width: CGFloat(newValue.width), height: CGFloat(newValue.height)))
        }
    }
}

#endif
