//
//  InputManager.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public final class Input {
    
    internal static let shared = Input()
    
    internal var mousePosition: Vector2 = .zero
    
    private var eventsPool: Set<Event> = []
    
    private var keyEvents: [KeyCode: KeyEvent] = [:]
    private var mouseEvents: Set<MouseEvent> = []
 
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
    
    public static func isActionPressed(_ action: String) -> Bool {
        fatalError()
    }
    
    public static func isActionRelease(_ action: String) -> Bool {
        fatalError()
    }
    
    public static func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        self.shared.mouseEvents.first { $0.button == button }?.phase == .began
    }
    
    public static func isMouseButtonRelease(_ button: MouseButton) -> Bool {
        fatalError()
    }
    
    public static func getMousePosition() -> Vector2 {
        return self.shared.mousePosition
    }
    
    
    // MARK: Internal
    
    func processEvents() {
        for event in eventsPool {
            
            switch event {
            case let keyEvent as KeyEvent:
                self.keyEvents[keyEvent.keyCode] = keyEvent
            case let mouseEvent as MouseEvent:
                self.mouseEvents.insert(mouseEvent)
            default:
                break
            }
        }
        
        self.eventsPool.removeAll()
    }
    
    func receiveEvent(_ event: Event) {
        self.eventsPool.insert(event)
    }
    
}

extension Input {
    public class Event: Hashable, Identifiable {
        
        public let time: TimeInterval
        
        internal init(time: TimeInterval) {
            self.time = time
        }
        
        public static func == (lhs: Input.Event, rhs: Input.Event) -> Bool {
            return lhs.time == rhs.time
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(time)
        }
        
    }
    
    public class KeyEvent: Event {
        
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
    
    public final class MouseEvent: Event {
        
        public enum Phase: UInt8, Hashable {
            case began
            case changed
            case ended
            case cancelled
        }
        
        let button: MouseButton
        let mousePosition: Vector2
        let phase: Phase
        
        init(button: MouseButton, mousePosition: Vector2, phase: Phase, time: TimeInterval) {
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
    
    public final class TouchEvent: Event {
        
        internal init(location: Vector2, time: TimeInterval) {
            self.location = location
            super.init(time: time)
        }
        
        public let location: Vector2
        
        public override func hash(into hasher: inout Hasher) {
            hasher.combine(location)
            hasher.combine(time)
        }
    }
}
