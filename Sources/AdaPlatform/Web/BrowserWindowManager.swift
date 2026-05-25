//
//  BrowserWindowManager.swift
//  AdaEngine
//

#if WASM && canImport(JavaScriptKit)
import AdaRender
import AdaUtils
@_spi(Internal) import AdaInput
import AdaUI
import Foundation
import JavaScriptKit
import Math

@MainActor
final class BrowserWindowManager: UIWindowManager {
    private let screenManager: BrowserScreenManager
    private var eventClosures: [UIWindow.ID: [JSClosure]] = [:]
    private var surfaces: [UIWindow.ID: BrowserRenderSurface] = [:]

    init(screenManager: BrowserScreenManager) {
        self.screenManager = screenManager
        super.init()
    }

    override func createWindow(for window: UIWindow) {
        let surface = BrowserRenderSurface(windowId: window.id, requestedSize: window.configuration.frame.size)
        surfaces[window.id] = surface
        window.systemWindow = BrowserSystemWindow(surface: surface, title: window.configuration.title ?? "AdaEngine")

        attachCanvas(surface.canvas)
        installEventHandlers(for: window, surface: surface)

        if unsafe RenderEngine.shared != nil {
            unsafe try? RenderEngine.shared.createWindow(window.id, for: surface, size: surface.logicalSize)
        }

        super.createWindow(for: window)
    }

    override func showWindow(_ window: UIWindow, isFocused: Bool) {
        if isFocused {
            setActiveWindow(window)
            _ = surfaces[window.id]?.canvas.focus()
        }
        window.windowDidAppear()
    }

    override func closeWindow(_ window: UIWindow) {
        guard window.windowShouldClose() else {
            return
        }

        surfaces[window.id]?.canvas.remove()
        surfaces[window.id] = nil
        eventClosures[window.id] = nil
        removeWindow(window)
    }

    override func resizeWindow(_ window: UIWindow, size: Size) {
        guard let surface = surfaces[window.id] else {
            return
        }

        surface.resize(to: size)
        unsafe try? RenderEngine.shared?.resizeWindow(window.id, newSize: surface.logicalSize, scaleFactor: surface.scaleFactor)
    }

    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {
        if mode == .fullscreen || mode == .fullScreenWindowed {
            _ = surfaces[window.id]?.canvas.requestFullscreen()
        }
    }

    override func setMinimumSize(_ size: Size, for window: UIWindow) { }

    override func getScreen(for window: UIWindow) -> Screen? {
        screenManager.getMainScreen()
    }

    override func setCursorShape(_ shape: Input.CursorShape) {
        activeWindow.flatMap { surfaces[$0.id] }?.setCursorShape(shape)
    }

    override func getCursorShape() -> Input.CursorShape {
        .arrow
    }

    override func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotspot: Vector2) { }

    override func setMouseMode(_ mode: Input.MouseMode) {
        guard let canvas = activeWindow.flatMap({ surfaces[$0.id]?.canvas }) else {
            return
        }

        switch mode {
        case .captured:
            _ = canvas.requestPointerLock()
        case .hidden, .confinedHidden:
            canvas.style.cursor = "none"
        case .visible, .confined:
            canvas.style.cursor = "default"
        }
    }

    override func getMouseMode() -> Input.MouseMode {
        .visible
    }

    override func updateCursor() { }

    private func attachCanvas(_ canvas: JSObject) {
        let document = JSObject.global.document
        let container = document.getElementById("ada-canvas-root").object ?? document.body.object!
        _ = container.appendChild(canvas)
    }

    private func installEventHandlers(for window: UIWindow, surface: BrowserRenderSurface) {
        var closures: [JSClosure] = []
        let canvas = surface.canvas

        closures.append(addEventListener("pointerdown", to: canvas) { [weak self, weak window, weak surface] event in
            self?.handlePointer(event, window: window, surface: surface, phase: .began)
        })
        closures.append(addEventListener("pointermove", to: canvas) { [weak self, weak window, weak surface] event in
            self?.handlePointer(event, window: window, surface: surface, phase: .changed)
        })
        closures.append(addEventListener("pointerup", to: canvas) { [weak self, weak window, weak surface] event in
            self?.handlePointer(event, window: window, surface: surface, phase: .ended)
        })
        closures.append(addEventListener("wheel", to: canvas) { [weak self, weak window, weak surface] event in
            self?.handleWheel(event, window: window, surface: surface)
        })
        closures.append(addEventListener("keydown", to: JSObject.global.window) { [weak self, weak window] event in
            self?.handleKey(event, window: window, status: .down)
        })
        closures.append(addEventListener("keyup", to: JSObject.global.window) { [weak self, weak window] event in
            self?.handleKey(event, window: window, status: .up)
        })
        closures.append(addEventListener("resize", to: JSObject.global.window) { [weak self, weak window, weak surface] _ in
            guard let self, let window, let surface else { return }
            let size = self.screenManager.getSize(for: self.screenManager.getMainScreen()!)
            surface.resize(to: size)
            window.frame.size = size
            unsafe try? RenderEngine.shared?.resizeWindow(window.id, newSize: surface.logicalSize, scaleFactor: surface.scaleFactor)
        })

        eventClosures[window.id] = closures
    }

    private func addEventListener(
        _ name: String,
        to target: JSObject,
        handler: @escaping @MainActor (JSObject) -> Void
    ) -> JSClosure {
        let closure = JSClosure { arguments in
            guard let event = arguments.first?.object else {
                return .undefined
            }

            Task { @MainActor in
                handler(event)
            }

            return .undefined
        }
        _ = target.addEventListener(name, .object(closure))
        return closure
    }

    private func handlePointer(_ event: JSObject, window: UIWindow?, surface: BrowserRenderSurface?, phase: MouseEvent.Phase) {
        guard let window, let surface, let inputRef else {
            return
        }

        _ = event.preventDefault()
        if phase == .began {
            setActiveWindow(window)
            _ = surface.canvas.focus()
        }

        inputRef.wrappedValue.receiveEvent(
            MouseEvent(
                window: window.id,
                button: MouseButton(rawValue: UInt8(event.button.number ?? 0) + 1) ?? .left,
                mousePosition: surface.location(from: event),
                phase: phase,
                modifierKeys: KeyModifier(browserEvent: event),
                time: Time.absolute
            )
        )
    }

    private func handleWheel(_ event: JSObject, window: UIWindow?, surface: BrowserRenderSurface?) {
        guard let window, let surface, let inputRef else {
            return
        }

        _ = event.preventDefault()
        inputRef.wrappedValue.receiveEvent(
            MouseEvent(
                window: window.id,
                button: .none,
                scrollDelta: Point(
                    x: Float(event.deltaX.number ?? 0),
                    y: Float(event.deltaY.number ?? 0)
                ),
                mousePosition: surface.location(from: event),
                phase: .changed,
                modifierKeys: KeyModifier(browserEvent: event),
                time: Time.absolute
            )
        )
    }

    private func handleKey(_ event: JSObject, window: UIWindow?, status: KeyEvent.Status) {
        guard let window = window ?? activeWindow, let inputRef else {
            return
        }

        inputRef.wrappedValue.receiveEvent(
            KeyEvent(
                window: window.id,
                keyCode: KeyCode(browserEvent: event),
                modifiers: KeyModifier(browserEvent: event),
                status: status,
                time: Time.absolute,
                isRepeated: event.repeat.boolean ?? false
            )
        )
    }
}

@MainActor
final class BrowserRenderSurface: RenderSurface {
    let windowId: WindowID
    let canvas: JSObject

    var scaleFactor: Float {
        Float(JSObject.global.window.devicePixelRatio.number ?? 1)
    }

    var prefferedPixelFormat: PixelFormat {
        .bgra8
    }

    var logicalSize: SizeInt {
        SizeInt(width: Int(size.width), height: Int(size.height))
    }

    private var size: Size

    init(windowId: WindowID, requestedSize: Size) {
        self.windowId = windowId
        let document = JSObject.global.document
        self.canvas = document.createElement("canvas").object!
        self.size = requestedSize == .zero
            ? Size(width: Float(JSObject.global.window.innerWidth.number ?? 800), height: Float(JSObject.global.window.innerHeight.number ?? 600))
            : requestedSize

        canvas.id = "ada-canvas-\(windowId)"
        canvas.tabIndex = 0
        canvas.style.display = "block"
        canvas.style.width = "\(Int(size.width))px"
        canvas.style.height = "\(Int(size.height))px"
        resizeBackingStore()
    }

    func resize(to newSize: Size) {
        self.size = newSize
        canvas.style.width = "\(Int(newSize.width))px"
        canvas.style.height = "\(Int(newSize.height))px"
        resizeBackingStore()
    }

    func location(from event: JSObject) -> Point {
        let rect = canvas.getBoundingClientRect()
        return Point(
            x: Float((event.clientX.number ?? 0) - (rect.left.number ?? 0)),
            y: Float((event.clientY.number ?? 0) - (rect.top.number ?? 0))
        )
    }

    func setCursorShape(_ shape: Input.CursorShape) {
        canvas.style.cursor = shape.browserCSSCursor
    }

    private func resizeBackingStore() {
        let scale = Double(scaleFactor)
        canvas.width = Int(Double(size.width) * scale)
        canvas.height = Int(Double(size.height) * scale)
    }
}

@MainActor
final class BrowserSystemWindow: SystemWindow {
    private let surface: BrowserRenderSurface

    var title: String {
        get { JSObject.global.document.title.string ?? "" }
        set { JSObject.global.document.title = .string(newValue) }
    }

    var size: Size {
        get { surface.logicalSize.toSize() }
        set { surface.resize(to: newValue) }
    }

    var position: Point = .zero

    init(surface: BrowserRenderSurface, title: String) {
        self.surface = surface
        self.title = title
    }
}

private extension SizeInt {
    func toSize() -> Size {
        Size(width: Float(width), height: Float(height))
    }
}

private extension KeyModifier {
    init(browserEvent event: JSObject) {
        self.init()
        if event.shiftKey.boolean == true { insert(.shift) }
        if event.ctrlKey.boolean == true { insert(.control) }
        if event.metaKey.boolean == true { insert(.main) }
        if event.altKey.boolean == true { insert(.alt) }
    }
}

private extension KeyCode {
    init(browserEvent event: JSObject) {
        let key = event.key.string ?? ""
        if key.count == 1, let scalar = key.lowercased().unicodeScalars.first {
            self = KeyCode(rawValue: String(scalar)) ?? .none
            return
        }

        switch key {
        case "Enter": self = .enter
        case "Escape": self = .escape
        case "Backspace": self = .backspace
        case "Tab": self = .tab
        case " ": self = .space
        case "Shift": self = .shift
        case "Control": self = .ctrl
        case "Alt": self = .alt
        case "Meta": self = .meta
        case "CapsLock": self = .capslock
        case "Delete": self = .delete
        case "Home": self = .home
        case "PageUp": self = .pageUp
        case "PageDown": self = .pageDown
        default: self = KeyCode(rawValue: key) ?? .none
        }
    }
}

private extension Input.CursorShape {
    var browserCSSCursor: String {
        switch self {
        case .arrow: "default"
        case .pointingHand: "pointer"
        case .iBeam: "text"
        case .wait, .busy: "wait"
        case .cross: "crosshair"
        case .drag, .drop: "grab"
        case .resizeLeft, .resizeRight, .resizeLeftRight: "ew-resize"
        case .resizeUp, .resizeDown, .resizeUpDown: "ns-resize"
        case .move: "move"
        case .forbidden: "not-allowed"
        case .help: "help"
        }
    }
}
#endif
