//
//  MacOSWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/29/22.
//

#if MACOS
import AppKit
import Math

// swiftlint:disable cyclomatic_complexity

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
            defer: false
        )
        
        systemWindow.contentView = metalView
        systemWindow.collectionBehavior = .fullScreenPrimary
        systemWindow.center()
        systemWindow.isRestorable = false
        systemWindow.acceptsMouseMovedEvents = true
        systemWindow.delegate = nsWindowDelegate
        systemWindow.backgroundColor = NSColor.black
        
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
    
    override func getScreen(for window: Window) -> Screen? {
        guard let nsWindow = window.systemWindow as? NSWindow, let screen = nsWindow.screen else {
            return nil
        }
        
        return ScreenManager.shared.makeScreen(from: screen)
    }
    
    private var currentShape: Input.CursorShape = .arrow
    private var mouseMode: Input.MouseMode = .visible
    private var cursors: [Input.CursorShape: (NSCursor, Texture2D, Vector2)] = [:]
    
    override func setCursorShape(_ shape: Input.CursorShape) {        
        self.currentShape = shape
        
        var cursor = NSCursor.current
        
        switch shape {
        case .arrow:
            cursor = .arrow
        case .pointingHand:
            cursor = .pointingHand
        case .iBeam:
            cursor = .iBeam
        case .wait:
            cursor = .arrow
        case .cross:
            cursor = .crosshair
        case .busy:
            cursor = .arrow
        case .drag:
            cursor = .dragCopy
        case .drop:
            cursor = .openHand
        case .resizeLeft:
            cursor = .resizeLeft
        case .resizeRight:
            cursor = .resizeRight
        case .resizeLeftRight:
            cursor = .resizeLeftRight
        case .resizeUp:
            cursor = .resizeUp
        case .resizeDown:
            cursor = .resizeDown
        case .resizeUpDown:
            cursor = .resizeUpDown
        case .move:
            cursor = .closedHand
        case .forbidden:
            cursor = .operationNotAllowed
        case .help:
            break
        }
        
        cursor.set()
    }
    
    override func updateCursor() {
        if let customCursor = self.cursors[self.currentShape]?.0 {
            customCursor.set()
        } else {
            self.setCursorShape(self.currentShape)
        }
    }
    
    override func getCursorShape() -> Input.CursorShape {
        return self.currentShape
    }
    
    override func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotspot: Vector2) {
        defer {
            updateCursor()
        }
        
        guard let texture = texture else {
            self.cursors[shape] = nil
            
            return
        }
        
        if self.cursors[shape]?.1 === texture && self.cursors[shape]?.2 == hotspot {
            return
        }
        
        var position: Vector2 = .one
        
        if let atlas = texture as? TextureAtlas.Slice {
            position = atlas.position
        }
        
        let image = texture.image
        
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: texture.width,
            pixelsHigh: texture.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: NSBitmapFormat(),
            bytesPerRow: texture.width * 4,
            bitsPerPixel: 32
        ) else {
            return
        }
        
        guard let pixels = bitmap.bitmapData else {
            return
        }
        
        let length = texture.height * texture.width
        
        for index in 0..<length {
            let rowIndex = index / texture.width + Int(position.y)
            let columnIndex = index % texture.width + Int(position.x)
            
            let color = image.getPixel(x: columnIndex, y: rowIndex)
            
            pixels[index * 4 + 0] = UInt8(clamp(color.red * 255.0, 0, 255))
            pixels[index * 4 + 1] = UInt8(clamp(color.green * 255.0, 0, 255))
            pixels[index * 4 + 2] = UInt8(clamp(color.blue * 255.0, 0, 255))
            pixels[index * 4 + 3] = UInt8(clamp(color.alpha * 255.0, 0, 255))
        }
        
        let nsImage = NSImage(size: CGSize(width: CGFloat(texture.width), height: CGFloat(texture.height)))
        nsImage.addRepresentation(bitmap)
        
        let cursor = NSCursor(
            image: nsImage,
            hotSpot: CGPoint(x: CGFloat(hotspot.x), y: CGFloat(hotspot.y))
        )
        
        self.cursors[shape] = (cursor, texture, hotspot)
    }
    
    override func setMouseMode(_ mode: Input.MouseMode) {
        if (self.mouseMode == mode) {
            return
        }
        
        self.mouseMode = mode
        
        switch mode {
        case .captured:
            break
        case .visible:
            NSCursor.unhide()
        case .hidden:
            NSCursor.hide()
        case .confinedHidden:
            break
        case .confined:
            break
        }
    }
    
    override func getMouseMode() -> Input.MouseMode {
        self.mouseMode
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
        
        try? RenderEngine.shared.resizeWindow(window.id, newSize: size)
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

// swiftlint:enable cyclomatic_complexity

#endif
