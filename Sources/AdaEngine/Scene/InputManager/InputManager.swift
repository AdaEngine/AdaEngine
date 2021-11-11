//
//  InputManager.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public final class Input {
    
    internal static let shared = Input()
    
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
    
    // MARK: Internal
    
    func processEvents() {
        for event in eventsPool {
            
            switch event {
            case let keyEvent as KeyEvent:
                self.keyEvents[keyEvent.keyCode] = keyEvent
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
        public let id: String = ""
        public let time: TimeInterval
        
        internal init(time: TimeInterval) {
            self.time = time
        }
        
        public static func == (lhs: Input.Event, rhs: Input.Event) -> Bool {
            return lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
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
            hasher.combine(id)
            hasher.combine(keyCode)
            hasher.combine(modifiers)
        }
        
    }
    
    public final class MouseEvent: Event {
        
    }
    
    public final class TouchEvent: Event {
        
        public enum Status: UInt8, Hashable {
            case began
            case moved
            case ended
            case cancelled
        }
        
        internal init(location: Vector2, status: Status, time: TimeInterval) {
            self.location = location
            self.status = status
            super.init(time: time)
        }
        
        public let location: Vector2
        public internal(set) var status: Status
        
        public override func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(location)
            hasher.combine(status)
            hasher.combine(time)
        }
    }
}
