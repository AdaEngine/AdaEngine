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
    
    public let button: MouseButton
    public let mousePosition: Point
    public let scrollDelta: Point
    public let modifierKeys: KeyModifier
    public let phase: Phase

    init(window: UIWindow.ID, button: MouseButton, scrollDelta: Point = .zero, mousePosition: Point, phase: Phase, modifierKeys: KeyModifier, time: TimeInterval) {
        self.scrollDelta = scrollDelta
        self.button = button
        self.mousePosition = mousePosition
        self.modifierKeys = modifierKeys
        self.phase = phase
        super.init(window: window, time: time)
    }
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(button)
        hasher.combine(time)
        hasher.combine(phase)
        hasher.combine(modifierKeys)
        hasher.combine(scrollDelta)
    }
    
    public static func == (lhs: MouseEvent, rhs: MouseEvent) -> Bool {
        return lhs.time == rhs.time && lhs.window == rhs.window && lhs.eventId == rhs.eventId && lhs.button == rhs.button && lhs.mousePosition == rhs.mousePosition && lhs.phase == rhs.phase && lhs.modifierKeys == rhs.modifierKeys
    }
}
