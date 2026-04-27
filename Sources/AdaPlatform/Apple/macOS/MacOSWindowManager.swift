//
//  MacOSWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/29/22.
//

#if MACOS
import AdaRender
@_spi(Internal) import AdaUI
import AppKit
import AdaInput
import AdaUtils
import Math

// swiftlint:disable cyclomatic_complexity
final class MacOSWindowManager: UIWindowManager {

    private lazy var nsWindowDelegate = NSWindowDelegateObject(windowManager: self)
    private unowned let screenManager: MacOSScreenManager

    init(_ screenManager: MacOSScreenManager) {
        self.screenManager = screenManager
        super.init()
    }

    private var menus: [UIWindow.ID: MacOSUIMenuBuilder] = [:]
    private var windowsPendingInitialCenter: Set<UIWindow.ID> = []
    private var windowsSynchronizingFromSystem: Set<UIWindow.ID> = []

    override func createWindow(for window: UIWindow) {
        let minSize = window.configuration.minimumSize
        
        let frame = window.frame
        let size = frame.size == .zero ? minSize : frame.size
        
        let contentRect = CGRect(
            x: CGFloat(frame.origin.x),
            y: CGFloat(frame.origin.y),
            width: CGFloat(size.width),
            height: CGFloat(size.height)
        )
        
        let rootContentView = NSView(frame: NSRect(origin: .zero, size: contentRect.size))
        rootContentView.autoresizesSubviews = true

        /// Register view in engine
        let metalView = MetalView(
            windowId: window.id,
            frame: NSRect(origin: .zero, size: contentRect.size)
        )
        metalView.allowsTransparency = window.configuration.background.isTransparent
        metalView.windowManager = self
        metalView.autoresizingMask = [.width, .height]
        rootContentView.addSubview(metalView)
        let sizeInt = SizeInt(width: Int(size.width), height: Int(size.height))

        let styleMask: NSWindow.StyleMask = switch window.configuration.chrome {
        case .standard:
            [.titled, .closable, .resizable, .miniaturizable]
        case .borderless:
            [.borderless]
        }

        let systemWindow = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        systemWindow.contentView = rootContentView
        systemWindow.collectionBehavior = collectionBehavior(for: window.configuration.collectionBehavior)
        if frame.origin == .zero {
            systemWindow.center()
            windowsPendingInitialCenter.insert(window.id)
        }
        systemWindow.isRestorable = false
        systemWindow.acceptsMouseMovedEvents = true
        systemWindow.delegate = nsWindowDelegate
        systemWindow.level = windowLevel(for: window.configuration.level)
        systemWindow.isOpaque = !window.configuration.background.isTransparent
        systemWindow.hasShadow = true
        systemWindow.backgroundColor = backgroundColor(for: window.configuration.background)
        window.systemWindow = systemWindow
        if let title = window.configuration.title {
            window.title = title
        }
        if window.frame.origin != .zero {
            window.frame = Rect(origin: .zero, size: size)
        }
        window.minSize = minSize
        window.setWindowMode(window.configuration.mode)
        window.userInterfaceIdiom = .desktop

        unsafe try? RenderEngine.shared.createWindow(window.id, for: metalView, size: sizeInt)
        
        super.createWindow(for: window)
    }

    override func menuBuilder(for window: UIWindow) -> (any UIMenuBuilder)? {
        if let builder = self.menus[window.id] {
            return builder
        } else {
            let builder = MacOSUIMenuBuilder(window: window)
            self.menus[window.id] = builder
            return builder
        }
    }

    override func showWindow(_ window: UIWindow, isFocused: Bool) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }

        if nsWindow.isMiniaturized {
            nsWindow.deminiaturize(nil)
        }

        if windowsPendingInitialCenter.remove(window.id) != nil {
            nsWindow.center()
        }
        
        if isFocused {
            nsWindow.makeKeyAndOrderFront(nil)
        } else if shouldOrderFrontRegardless(window) {
            nsWindow.orderFrontRegardless()
        } else {
            nsWindow.orderFront(nil)
        }
        
        window.windowDidAppear()
        self.setActiveWindow(window)
    }
    
    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }
        
        let isFullScreen = nsWindow.styleMask.contains(.fullScreen)
        let shouldToggleFullScreen = isFullScreen != (mode == .fullscreen)
        
        if shouldToggleFullScreen {
            nsWindow.toggleFullScreen(nil)
        }
    }
    
    override func closeWindow(_ window: UIWindow) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }

        self.removeWindow(window, setActiveAnotherIfNeeded: true)
        windowsPendingInitialCenter.remove(window.id)
        
        nsWindow.close()
    }
    
    override func resizeWindow(_ window: UIWindow, size: Size) {
        guard !windowsSynchronizingFromSystem.contains(window.id) else {
            return
        }

        let nsWindow = window.systemWindow as? NSWindow

        let cgSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
        if nsWindow?.contentView?.frame.size != cgSize {
            nsWindow?.setContentSize(cgSize)
        }
    }
    
    override func setMinimumSize(_ size: Size, for window: UIWindow) {
        guard let nsWindow = window.systemWindow as? NSWindow else {
            fatalError("System window not exist.")
        }

        let minSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
        
        nsWindow.contentMinSize = minSize
        nsWindow.minSize = minSize
    }
    
    override func getScreen(for window: UIWindow) -> Screen? {
        guard
            let nsWindow = window.systemWindow as? NSWindow,
            let screen = nsWindow.screen
        else {
            return nil
        }
        
        return screenManager.makeScreen(from: screen)
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
    
    // swiftlint:disable:next function_body_length
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
        guard let bitmap = unsafe NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: texture.width,
            pixelsHigh: texture.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: NSBitmapImageRep.Format(),
            bytesPerRow: texture.width * 4,
            bitsPerPixel: 32
        ) else {
            return
        }
        
        guard let pixels = unsafe bitmap.bitmapData else {
            return
        }
        
        let length = texture.height * texture.width
        
        for index in 0..<length {
            let rowIndex = index / texture.width + Int(position.y)
            let columnIndex = index % texture.width + Int(position.x)
            
            let color = image.getPixel(x: columnIndex, y: rowIndex)
            
            unsafe pixels[index * 4 + 0] = UInt8(clamp(color.red * 255.0, 0, 255))
            unsafe pixels[index * 4 + 1] = UInt8(clamp(color.green * 255.0, 0, 255))
            unsafe pixels[index * 4 + 2] = UInt8(clamp(color.blue * 255.0, 0, 255))
            unsafe pixels[index * 4 + 3] = UInt8(clamp(color.alpha * 255.0, 0, 255))
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
    
    func findWindow(for nsWindow: NSWindow) -> UIWindow? {
        return self.windows.first {
            ($0.systemWindow as? NSWindow) === nsWindow
        }
    }

    func synchronizeRenderMetrics(for nsWindow: NSWindow, window: UIWindow, updateWindowFrame: Bool) {
        let size = nsWindow.size

        if updateWindowFrame && window.frame.size != size {
            windowsSynchronizingFromSystem.insert(window.id)
            defer {
                windowsSynchronizingFromSystem.remove(window.id)
            }
            window.frame = Rect(origin: .zero, size: size)
        }

        if let metalView = nsWindow.contentView?.subviews.first(where: { $0 is MetalView }) as? MetalView {
            metalView.updateDrawableMetrics()
        }

        window.setNeedsLayout()

        let sizeInt = SizeInt(width: Int(size.width), height: Int(size.height))
        unsafe try? RenderEngine.shared.resizeWindow(window.id, newSize: sizeInt)
    }

    private func backgroundColor(for background: UIWindow.Background) -> NSColor {
        switch background {
        case .transparent:
            return .clear
        case .opaque(let color):
            return NSColor(
                red: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: CGFloat(color.alpha)
            )
        }
    }

    private func windowLevel(for level: UIWindow.Level) -> NSWindow.Level {
        switch level {
        case .normal:
            return .normal
        case .floating:
            return .floating
        case .statusBar:
            return .screenSaver
        }
    }

    private func collectionBehavior(for behavior: UIWindow.CollectionBehavior) -> NSWindow.CollectionBehavior {
        switch behavior {
        case .standard:
            return .fullScreenPrimary
        case .allSpacesStationary:
            return [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }
    }

    private func shouldOrderFrontRegardless(_ window: UIWindow) -> Bool {
        switch window.configuration.level {
        case .normal:
            switch window.configuration.collectionBehavior {
            case .standard:
                return false
            case .allSpacesStationary:
                return true
            }
        case .floating, .statusBar:
            return true
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
        
        windowManager.synchronizeRenderMetrics(for: nsWindow, window: window, updateWindowFrame: true)
    }

    func windowDidChangeBackingProperties(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }

        windowManager.synchronizeRenderMetrics(for: nsWindow, window: window, updateWindowFrame: false)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }

        NotificationCenter.default.post(name: .adaEngineWindowDidMiniaturize, object: window)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        guard
            let nsWindow = notification.object as? NSWindow,
            let window = self.windowManager.findWindow(for: nsWindow)
        else {
            return
        }

        NotificationCenter.default.post(name: .adaEngineWindowDidDeminiaturize, object: window)
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

final class MacOSUIMenuBuilder: UIMenuBuilder {

    private weak var window: UIWindow?
    private var isNeedsUpdate = true

    private var menu: NSMenu? {
        return (window?.systemWindow as? NSWindow)?.menu
    }

    init(window: UIWindow) {
        self.window = window
    }

    func insert(_ menu: UIMenu) {
        let nsMenu = makeNSMenu(from: menu)

        let menuItem = NSMenuItem()
        menuItem.title = menu.title
        self.menu?.addItem(menuItem)
        self.menu?.setSubmenu(nsMenu, for: menuItem)
    }

    func remove(_ menu: UIMenu.ID) {

    }

    func setNeedsUpdate() {
        self.isNeedsUpdate = true
    }

    func updateIfNeeded() {
        guard isNeedsUpdate else {
            return
        }

        self.window?._buildMenu(with: self)
        self.isNeedsUpdate = false
    }

    private func makeNSMenu(from menu: UIMenu) -> NSMenu {
        let nsMenu = NSMenu(title: menu.title)
        let items = menu.items.map(makeNSMenuItem(from:))

        for item in items {
            nsMenu.addItem(item)
        }

        return nsMenu
    }

    private func makeNSMenuItem(from item: MenuItem) -> NSMenuItem {
        if item.isSeparator {
            return .separator()
        }

        let nsItem = NSMenuItem()
        nsItem.title = item.title
        nsItem.target = self
        nsItem.action = #selector(onActionPressed)
        nsItem.submenu = item.submenu.flatMap { self.makeNSMenu(from: $0) }
        nsItem.representedObject = item
        if let key = item.keyEquivalent?.rawValue {
            nsItem.keyEquivalent = key
        }
        if let modifier = item.keyEquivalentModifierMask {
            nsItem.keyEquivalentModifierMask = makeKeyModifierMask(from: modifier)
        }

        return nsItem
    }

    private func makeKeyModifierMask(from modifier: KeyModifier) -> NSEvent.ModifierFlags {
        var keyModifiers = NSEvent.ModifierFlags()

        if modifier.contains(.alt) {
            keyModifiers.insert(.option)
        }

        if modifier.contains(.main) {
            keyModifiers.insert(.command)
        }

        if modifier.contains(.control) {
            keyModifiers.insert(.control)
        }

        if modifier.contains(.shift) {
            keyModifiers.insert(.shift)
        }

        if modifier.contains(.capsLock) {
            keyModifiers.insert(.capsLock)
        }

        return keyModifiers
    }

    @objc func onActionPressed(_ nsItem: NSMenuItem) {
        guard let item = nsItem.representedObject as? MenuItem else {
            return
        }

        item.action?()
    }
}

// swiftlint:enable cyclomatic_complexity

#endif
