//
//  InputManager.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// - TODO: (Vlad) Input manager doesn't work if keyboard set to cirillic mode.
// - TODO: (Vlad) Add touches handling
public final class Input {
    
    internal static let shared = Input()
    
    internal var mousePosition: Point = .zero
    
    internal var eventsPool: Set<InputEvent> = []
    
    // FIXME: (Vlad) Should think about capacity. We should store ~256 keycode events
    internal private(set) var keyEvents: [KeyCode: KeyEvent] = [:]
    internal private(set) var mouseEvents: [MouseButton: MouseEvent] = [:]
    internal private(set) var touches: Set<TouchEvent> = []
    
    // MARK: - Public Methods
    
    public static func getTouches() -> Set<TouchEvent> {
        return self.shared.touches
    }
    
    public static func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        return self.shared.keyEvents[keyCode]?.status == .down
    }
    
    public static func isKeyPressed(_ keyCode: String) -> Bool {
        guard let code = KeyCode(rawValue: keyCode) else {
            return false
        }
        
        return self.shared.keyEvents[code]?.status == .down
    }
    
    public static func isKeyRelease(_ keyCode: KeyCode) -> Bool {
        return self.shared.keyEvents[keyCode]?.status == .up
    }
    
    public static func isKeyRelease(_ keyCode: String) -> Bool {
        guard let code = KeyCode(rawValue: keyCode) else {
            return false
        }
        return self.shared.keyEvents[code]?.status == .up
    }
    
    // TODO: (Vlad) Make action list
    public static func isActionPressed(_ action: String) -> Bool {
        fatalError()
    }
    
    public static func isActionRelease(_ action: String) -> Bool {
        fatalError()
    }
    
    public static func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        guard let phase = self.shared.mouseEvents[button]?.phase else {
            return false
        }
        
        return phase == .began || phase == .changed
    }
    
    public static func isMouseButtonRelease(_ button: MouseButton) -> Bool {
        return self.shared.mouseEvents[button]?.phase == .ended
    }
    
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
