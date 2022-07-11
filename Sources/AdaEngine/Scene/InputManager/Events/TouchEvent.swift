//
//  TouchEvent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

public final class TouchEvent: InputEvent {
    
    internal init(window: Window.ID, location: Point, time: TimeInterval) {
        self.location = location
        super.init(window: window, time: time)
    }
    
    public let location: Point
    
    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(location)
        hasher.combine(time)
    }
}
