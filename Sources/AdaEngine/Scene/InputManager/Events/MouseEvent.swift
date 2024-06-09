//
//  MouseEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

/// An object that contains information about mouse event.
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
    
    init(window: UIWindow.ID, button: MouseButton, mousePosition: Point, phase: Phase, time: TimeInterval) {
        self.button = button
        self.mousePosition = mousePosition
        self.phase = phase
        super.init(window: window, time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(button)
        hasher.combine(time)
        hasher.combine(phase)
    }
    
    public static func == (lhs: MouseEvent, rhs: MouseEvent) -> Bool {
        return lhs.time == rhs.time && lhs.window == rhs.window && lhs.eventId == rhs.eventId && lhs.button == rhs.button && lhs.mousePosition == rhs.mousePosition && lhs.phase == rhs.phase
    }
}
