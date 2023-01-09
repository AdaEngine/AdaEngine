//
//  TouchEvent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

public final class TouchEvent: InputEvent {
    
    public enum Phase: Equatable, Hashable {
        case began
        case moved
        case ended
        case cancelled
    }
    
    internal init(window: Window.ID, location: Point, phase: Phase, time: TimeInterval) {
        self.location = location
        self.phase = phase
        super.init(window: window, time: time)
    }
    
    public let location: Point
    public let phase: Phase
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(location)
        hasher.combine(time)
        hasher.combine(phase)
    }
    
    public static func == (lhs: TouchEvent, rhs: TouchEvent) -> Bool {
        return lhs.time == rhs.time && lhs.window == rhs.window && lhs.eventId == rhs.eventId && lhs.phase == rhs.phase && lhs.location == rhs.location
    }
}
