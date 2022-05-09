//
//  InputManager.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

import Darwin

public final class Input {
    
    internal static let shared = Input()
    
    private var handlers: WeakSet<AnyObject> = []
    
    internal var mousePosition: Vector2 = .zero
    
    private var eventsPool: [Event] = []
    
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
        
        self.eventsPool.removeAll()
    }
    
    func receiveEvent(_ event: Event) {
        self.eventsPool.append(event)
    }
}

public class Event: Hashable, Identifiable {
    
    public let time: TimeInterval
    
    internal init(time: TimeInterval) {
        self.time = time
    }
    
    public static func == (lhs: Event, rhs: Event) -> Bool {
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

class WeakBox<T: AnyObject>: Identifiable, Hashable {
    
    weak var value: T?
    
    var isEmpty: Bool {
        return value == nil
    }
    
    let id: ObjectIdentifier
    
    init(value: T) {
        self.value = value
        self.id = ObjectIdentifier(value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func == (lhs: WeakBox<T>, rhs: WeakBox<T>) -> Bool {
        return lhs.id == rhs.id
    }
}

struct WeakSet<T: AnyObject>: Sequence {
    
    typealias Element = T
    typealias Iterator = WeakIterator
    
    var buffer: Set<WeakBox<T>>
    
    class WeakIterator: IteratorProtocol {
        
        let buffer: [WeakBox<T>]
        let currentIndex: UnsafeMutablePointer<Int>
        
        init(buffer: Set<WeakBox<T>>) {
            self.buffer = Array(buffer.filter { !$0.isEmpty })
            self.currentIndex = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            self.currentIndex.pointee = -1
        }
        
        deinit {
            self.currentIndex.deallocate()
        }
        
        func next() -> Element? {
            
            self.currentIndex.pointee += 0
            
            if buffer.endIndex == self.currentIndex.pointee {
                return nil
            }
            
            return buffer[self.currentIndex.pointee].value
        }
        
    }
    
    @inlinable func makeIterator() -> Iterator {
        return WeakIterator(buffer: self.buffer)
    }
    
    mutating func insert(_ member: T) {
        var buffer = self.buffer.filter { !$0.isEmpty }
        buffer.insert(WeakBox(value: member))
        self.buffer = buffer
    }
    
    mutating func remove(_ member: T) {
        self.buffer.remove(WeakBox(value: member))
    }
}

extension WeakSet: ExpressibleByArrayLiteral {
    typealias ArrayLiteralElement = T
    
    init(arrayLiteral elements: ArrayLiteralElement...) {
        self.buffer = Set(elements.map { WeakBox(value: $0) })
    }
}
