//
//  InputEvent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

/// Base class for all input events
public class InputEvent: Hashable, Identifiable {
    
    public let window: Window.ID
    public let time: TimeInterval
    public let eventId = RID()
    
    internal init(window: Window.ID, time: TimeInterval) {
        self.window = window
        self.time = time
    }
    
    public static func == (lhs: InputEvent, rhs: InputEvent) -> Bool {
        return lhs.time == rhs.time && lhs.window == rhs.window && lhs.eventId == rhs.eventId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(time)
        hasher.combine(window)
        hasher.combine(eventId)
    }
}
