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

// - TODO: (Vlad) Input manager doesn't work if keyboard set to cirillic mode.

/// An object that contains inputs from keyboards, mouse, touch screens and etc.
public final class Input {
    
    internal static let shared = Input()
    
    internal var mousePosition: Point = .zero
    
    internal var eventsPool: Set<InputEvent> = []
    
    // FIXME: (Vlad) Should think about capacity. We should store ~256 keycode events
    internal private(set) var keyEvents: [KeyCode: KeyEvent] = [:]
    internal private(set) var mouseEvents: [MouseButton: MouseEvent] = [:]
    internal private(set) var touches: Set<TouchEvent> = []
    
    // MARK: - Public Methods
    
    /// Returns set of touches on screens.
    public static func getTouches() -> Set<TouchEvent> {
        return self.shared.touches
    }
    
    /// Returns `true` if you are pressing the Latin key in the current keyboard layout.
    public static func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        return self.shared.keyEvents[keyCode]?.status == .down
    }
    
    /// Returns `true` if you are pressing the Latin key in the current keyboard layout.
    public static func isKeyPressed(_ keyCode: String) -> Bool {
        guard let code = KeyCode(rawValue: keyCode) else {
            return false
        }
        
        return self.shared.keyEvents[code]?.status == .down
    }
    
    /// Returns `true` when the user stops pressing the key button, meaning it's true only on the frame that the user released the button.
    public static func isKeyRelease(_ keyCode: KeyCode) -> Bool {
        return self.shared.keyEvents[keyCode]?.status == .up
    }
    
    /// Returns `true` when the user stops pressing the key button, meaning it's true only on the frame that the user released the button.
    public static func isKeyRelease(_ keyCode: String) -> Bool {
        guard let code = KeyCode(rawValue: keyCode) else {
            return false
        }
        return self.shared.keyEvents[code]?.status == .up
    }
    
    // TODO: (Vlad) Make action list
    static func isActionPressed(_ action: String) -> Bool {
        fatalError()
    }

    static func isActionRelease(_ action: String) -> Bool {
        fatalError()
    }
    
    /// Returns true if you are pressing the mouse button specified with MouseButton.
    public static func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        guard let phase = self.shared.mouseEvents[button]?.phase else {
            return false
        }
        
        return phase == .began || phase == .changed
    }
    
    public static func isMouseButtonRelease(_ button: MouseButton) -> Bool {
        return self.shared.mouseEvents[button]?.phase == .ended
    }
    
    /// Get mouse position on window.
    public static func getMousePosition() -> Vector2 {
        return self.shared.mousePosition
    }
    
    // MARK: Internal
    
    // TODO: (Vlad) Think about moving this code to receiveEvent(_:) method
    func processEvents() {
        for event in eventsPool {
            switch event {
            case let keyEvent as KeyEvent:
                self.keyEvents[keyEvent.keyCode] = keyEvent
            case let mouseEvent as MouseEvent:
                self.mouseEvents[mouseEvent.button] = mouseEvent
            case let touchEvent as TouchEvent:
                self.touches.insert(touchEvent)
            default:
                break
            }
        }
    }
    
    func removeEvents() {
        self.eventsPool.removeAll()
    }
    
    func receiveEvent(_ event: InputEvent) {
        self.eventsPool.insert(event)
    }
}
