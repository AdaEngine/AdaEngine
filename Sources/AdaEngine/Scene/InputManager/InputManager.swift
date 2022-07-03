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

public final class Input {
    
    internal static let shared = Input()
    
    private var handlers: WeakSet<AnyObject> = []
    
    internal var mousePosition: Point = .zero
    
    internal var eventsPool: [InputEvent] = []
    
    internal private(set) var keyEvents: [KeyCode: KeyEvent] = [:]
    internal private(set) var mouseEvents: [MouseButton: MouseEvent] = [:]
    
    public static var horizontal: Bool {
        fatalError("")
    }
    
    public static var vertical: Bool {
        fatalError("")
    }
    
    // MARK: - Public Methods
    
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
    
    // TODO: Make action list
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
    
    public static func subscribe(_ handler: InputEventHandler) {
        self.shared.handlers.insert(handler)
    }
    
    public static func unsubscribe(_ handler: InputEventHandler) {
        self.shared.handlers.remove(handler)
    }
    
    // MARK: Internal
    
    func processEvents() {
        for event in eventsPool {
            
            switch event {
            case let keyEvent as KeyEvent:
                self.keyEvents[keyEvent.keyCode] = keyEvent
            case let mouseEvent as MouseEvent:
                self.mouseEvents[mouseEvent.button] = mouseEvent
            default:
                break
            }
        }
    }
    
    func removeEvents() {
        self.eventsPool.removeAll()
    }
    
    func receiveEvent(_ event: InputEvent) {
        self.eventsPool.append(event)
    }
}

public class InputEvent: Hashable, Identifiable {
    
    public let time: TimeInterval
    
    internal init(time: TimeInterval) {
        self.time = time
    }
    
    public static func == (lhs: InputEvent, rhs: InputEvent) -> Bool {
        return lhs.time == rhs.time
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(time)
    }
    
}

public class KeyEvent: InputEvent {
    
    public enum Status: UInt8, Hashable {
        case up
        case down
    }
    
    public let keyCode: KeyCode
    public let modifiers: KeyModifier
    public let status: Status
    
    internal init(keyCode: KeyCode, modifiers: KeyModifier, status: Status, time: TimeInterval) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.status = status
        
        super.init(time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
    
}

public final class MouseEvent: InputEvent {
    
    public enum Phase: UInt8, Hashable {
        case began
        case changed
        case ended
        case cancelled
    }
    
    let button: MouseButton
    let mousePosition: Point
    let phase: Phase
    
    init(button: MouseButton, mousePosition: Point, phase: Phase, time: TimeInterval) {
        self.button = button
        self.mousePosition = mousePosition
        self.phase = phase
        super.init(time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(button)
        hasher.combine(time)
        hasher.combine(phase)
    }
}

public final class TouchEvent: InputEvent {
    
    internal init(location: Point, time: TimeInterval) {
        self.location = location
        super.init(time: time)
    }
    
    public let location: Point
    
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(location)
        hasher.combine(time)
    }
}

public protocol InputEventHandler: AnyObject {
    func mouseUp(_ event: MouseEvent)
    
    func mouseDown(_ event: MouseEvent)
    
    func keyUp(_ event: KeyEvent)
    
    func keyDown(_ event: KeyEvent)
}

public extension InputEventHandler {
    func mouseUp(_ event: MouseEvent) { }
    
    func mouseDown(_ event: MouseEvent) { }
    
    func keyUp(_ event: KeyEvent) { }
    
    func keyDown(_ event: KeyEvent) { }
}
