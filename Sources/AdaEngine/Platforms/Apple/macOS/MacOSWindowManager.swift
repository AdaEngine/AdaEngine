//
//  File.swift
//  
//
//  Created by v.prusakov on 5/29/22.
//

#if os(macOS)
import Foundation
import AppKit

class MacOSWindowManager: WindowManager {
    
    private lazy var nsWindowDelegate = NSWindowDelegateObject(windowManager: self)
    
    override func createWindow(for window: Window) {
        super.createWindow(for: window)
        
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
        systemWindow.center()
        systemWindow.delegate = nsWindowDelegate
        
        window.systemWindow = systemWindow
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

extension NSWindow: SystemWindow {
    public var position: Point {
        get {
            Point(x: Float(self.frame.origin.x), y: Float(self.frame.origin.y))
        }
        set {
            self.setFrameOrigin(NSPoint(x: CGFloat(newValue.x), y: CGFloat(newValue.y)))
        }
    }
    
    public var size: Size {
        get {
            Size(width: Float(self.frame.size.width), height: Float(self.frame.size.height))
        }
        set {
            self.setContentSize(NSSize(width: CGFloat(newValue.width), height: CGFloat(newValue.height)))
        }
    }
}

// MARK: - NSWindowDelegate

final class NSWindowDelegateObject: NSObject, NSWindowDelegate {
    
    unowned let windowManager: MacOSWindowManager
    
    init(windowManager: MacOSWindowManager) {
        self.windowManager = windowManager
    }
    
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
        try? RenderEngine.shared.renderBackend.resizeWindow(window.id, newSize: size)
    }
}

#endif
