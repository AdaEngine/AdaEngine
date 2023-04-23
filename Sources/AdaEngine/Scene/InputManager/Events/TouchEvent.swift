//
//  TouchEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

// TODO: (Vlad) Number of taps?
// TODO: (Vlad) finger index?
// TODO: (Vlad) Angles?
// TODO: (Vlad) radius of pressure?

/// Event describing the status of a finger touching the screen.
public final class TouchEvent: InputEvent {
    
    /// Describe the phase of a finger touch
    public enum Phase: Equatable, Hashable {
        case began
        case moved
        case ended
        case cancelled
    }
    
    /// The position of the touch in screen space pixel coordinates.
    public let location: Point
    
    /// Describe the phase of a finger touch
    public let phase: Phase
    
    internal init(window: Window.ID, location: Point, phase: Phase, time: TimeInterval) {
        self.location = location
        self.phase = phase
        super.init(window: window, time: time)
    }
    
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
