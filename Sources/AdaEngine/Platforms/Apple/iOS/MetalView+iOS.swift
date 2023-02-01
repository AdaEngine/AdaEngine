//
//  File.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

#if os(iOS)
import UIKit

extension MetalView {
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            
            let event = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .began,
                time: TimeInterval(event?.timestamp ?? 0)
            )
            
            Input.shared.receiveEvent(event)
        }
    }
    
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            
            let event = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .moved,
                time: TimeInterval(event?.timestamp ?? 0)
            )
            
            Input.shared.receiveEvent(event)
        }
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            
            let event = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .cancelled,
                time: TimeInterval(event?.timestamp ?? 0)
            )
            
            Input.shared.receiveEvent(event)
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            
            let event = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .ended,
                time: TimeInterval(event?.timestamp ?? 0)
            )
            
            Input.shared.receiveEvent(event)
        }
    }
}

#endif
