//
//  MouseEvent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

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
    
    init(window: Window.ID, button: MouseButton, mousePosition: Point, phase: Phase, time: TimeInterval) {
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
}
