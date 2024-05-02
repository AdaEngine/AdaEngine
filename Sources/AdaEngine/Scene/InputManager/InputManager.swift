//
//  InputManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// - TODO: (Vlad) Add actions list and method like `isActionPressed`

/// An object that contains inputs from keyboards, mouse, touch screens and etc.
public final class Input {
    
    internal static let shared = Input()
    
    internal var mousePosition: Point = .zero

    private static let lock = NSLock()

    internal private(set) var eventsPool: [InputEvent] = []

    // FIXME: (Vlad) Should think about capacity. We should store ~256 keycode events
    internal private(set) var keyEvents: Set<KeyCode> = []
    internal private(set) var mouseEvents: [MouseButton: MouseEvent] = [:]
    internal private(set) var touches: Set<TouchEvent> = []

    private init() {}

    // MARK: - Public Methods
    
    /// Returns set of touches on screens.
    public static func getTouches() -> Set<TouchEvent> {
        lock.lock()
        defer { lock.unlock() }
        
        return self.shared.touches
    }

    public static func getInputEvents() -> Set<InputEvent> {
        lock.lock()
        defer { lock.unlock() }

        return Set(self.shared.eventsPool)
    }

    /// Returns `true` if you are pressing the Latin key in the current keyboard layout.
    public static func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return self.shared.keyEvents.contains(keyCode)
    }
    
    /// Returns true if you are pressing the mouse button specified with MouseButton.
    public static func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let phase = self.shared.mouseEvents[button]?.phase else {
            return false
        }
        
        return phase == .began || phase == .changed
    }
    
    /// Returns `true` if you are released the mouse button.
    public static func isMouseButtonRelease(_ button: MouseButton) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return self.shared.mouseEvents[button]?.phase == .ended
    }
    
    /// Get mouse position on window.
    public static func getMousePosition() -> Vector2 {
        lock.lock()
        defer { lock.unlock() }

        return self.shared.mousePosition
    }
    
    /// Get mouse mode for active window.
    @MainActor
    public static func getMouseMode() -> MouseMode {
        Application.shared.windowManager.getMouseMode()
    }
    
    /// Set mouse mode for active window.
    @MainActor
    public static func setMouseMode(_ mode: MouseMode) {
        Application.shared.windowManager.setMouseMode(mode)
    }
    
    /// Set current cursor shape.
    @MainActor
    public static func setCursorShape(_ shape: CursorShape) {
        Application.shared.windowManager.setCursorShape(shape)
    }
    
    /// Set custom image for cursor.
    /// - Parameter shape: What cursor shape will update the texture.
    /// - Parameter texture: Texture for cursor, also available ``TextureAtlas``. If you pass nil, then we remove saved image.
    /// - Parameter hotSpot: The point to set as the cursor's hot spot.
    @MainActor
    public static func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotSpot: Vector2 = .zero) {
        Application.shared.windowManager.setCursorImage(for: shape, texture: texture, hotspot: hotSpot)
    }
    
    /// Get current cursor shape.
    @MainActor
    public static func getCurrentCursorShape() -> CursorShape {
        Application.shared.windowManager.getCursorShape()
    }
    
    // MARK: Internal
    
    @MainActor
    func removeEvents() {
        self.eventsPool.removeAll()
    }
    
    @MainActor
    func receiveEvent(_ event: InputEvent) {
        self.eventsPool.append(event)
        self.parseInputEvent(event)
    }

    // MARK: - Private

    private func parseInputEvent(_ event: InputEvent) {
        switch event {
        case let keyEvent as KeyEvent:
            if keyEvent.keyCode == .none && keyEvent.isRepeated {
                return
            }

            if keyEvent.status == .down {
                self.keyEvents.insert(keyEvent.keyCode)
            } else {
                self.keyEvents.remove(keyEvent.keyCode)
            }
        case let mouseEvent as MouseEvent:
            self.mouseEvents[mouseEvent.button] = mouseEvent
        case let touchEvent as TouchEvent:
            self.touches.insert(touchEvent)
        default:
            break
        }
    }
}

public extension Input {
    
    /// Available list of mouse modes.
    enum MouseMode {
        
        /// Captures the mouse. The mouse will be hidden and its position locked at the center of the window manager's window.
        /// - WARNING: Not supported.
        case captured
        
        /// Makes the mouse cursor visible if it is hidden.
        case visible
        
        /// Makes the mouse cursor hidden if it is visible.
        case hidden
        
        /// Confines the mouse cursor to the game window, and make it hidden.
        /// - WARNING: Not supported.
        case confinedHidden
        
        /// Confines the mouse cursor to the game window, and make it visible.
        /// - WARNING: Not supported.
        case confined
    }
    
    /// Available list of cursor shapes.
    enum CursorShape {
        
        /// Standard cursor.
        case arrow
        
        /// Ussually used to show a link or other interactive item.
        case pointingHand
        
        /// Usually used to show where the text cursor will appear.
        case iBeam
        
        /// Usually used to show that application is busy and performing some operation. Also automatically shown when something blocking the main thread.
        case wait
        
        /// Typically appears over regions in which a drawing operation can be performed or for selections.
        case cross
        
        /// Busy cursor. Indicates that the application is busy performing an operation.
        case busy
        
        /// Drag cursor. Usually displayed when dragging something.
        case drag
        
        /// Can drop cursor. Usually displayed when dragging something to indicate that it can be dropped at the current position.
        case drop
        
        /// Used to indicate resizing to left.
        case resizeLeft
        
        /// Used to indicate resizing to right.
        case resizeRight
        
        /// Used to indicate horizontal resizing.
        case resizeLeftRight
        
        /// Used to indicate resizing to up.
        case resizeUp
        
        /// Used to indicate resizing to down.
        case resizeDown
        
        /// Used to indicate vertical resizing.
        case resizeUpDown
        
        /// Move cursor. Indicates that something can be moved.
        case move
        
        /// Forbidden cursor. Indicates that the current action is forbidden (for example, when dragging something) or that the control at a position is disabled.
        case forbidden
        
        /// Usually a question mark indicate some help.
        case help
    }
}
