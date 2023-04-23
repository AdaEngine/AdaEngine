//
//  KeyEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

/// An object that contains information about keyboard event.
public class KeyEvent: InputEvent {
    
    public enum Status: UInt8, Hashable {
        case up
        case down
    }
    
    public let keyCode: KeyCode
    public let modifiers: KeyModifier
    public let status: Status
    
    internal init(window: Window.ID, keyCode: KeyCode, modifiers: KeyModifier, status: Status, time: TimeInterval) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.status = status
        
        super.init(window: window, time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
    
    public static func == (lhs: KeyEvent, rhs: KeyEvent) -> Bool {
        return lhs.time == rhs.time && lhs.window == rhs.window && lhs.eventId == rhs.eventId && lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
    
}
