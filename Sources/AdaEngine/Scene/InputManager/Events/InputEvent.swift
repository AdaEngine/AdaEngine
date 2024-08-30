//
//  InputEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

// TODO: (Vlad) Should we know information about viewport where event happend?
// TODO: (Vlad) Should we use protocol instead of inheritence the base class?

/// Base class for all input events.
public class InputEvent: Hashable, Identifiable, Event, @unchecked Sendable {
    
    public let window: UIWindow.ID
    public let time: TimeInterval
    public let eventId = RID()
    
    internal init(window: UIWindow.ID, time: TimeInterval) {
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
