//
//  MetalView+macOS.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

#if MACOS

import AppKit

extension MetalView {
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func updateTrackingAreas() {
        if let area = self.currentTrackingArea {
            self.removeTrackingArea(area)
        }
        
        let options: NSTrackingAreaOptions = NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate | NSTrackingInVisibleRect | NSTrackingActiveInKeyWindow
        
        let newTrackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(newTrackingArea)
        
        self.currentTrackingArea = newTrackingArea
        
        super.updateTrackingAreas()
    }
    
    public override func touchesBegan(with event: NSEvent) {
        
    }
    
    public override func touchesMoved(with event: NSEvent) {
        
    }
    
    public override func touchesEnded(with event: NSEvent) {
        
    }
    
    public override func touchesCancelled(with event: NSEvent) {
        
    }
    
    public override func mouseUp(with event: NSEvent) {
        let position = self.mousePosition(for: event)
        
        let mouseEvent = MouseEvent(
            window: self.windowID,
            button: .left,
            mousePosition: position,
            phase: .ended,
            time: TimeInterval(event.timestamp)
        )
        
        Input.shared.mousePosition = position
        Input.shared.receiveEvent(mouseEvent)
    }
    
    public override func mouseDown(with event: NSEvent) {
        let position = self.mousePosition(for: event)
        
        let isContinious = Input.shared.mouseEvents[.left]?.phase == .began
        
        let mouseEvent = MouseEvent(
            window: self.windowID,
            button: .left,
            mousePosition: position,
            phase: isContinious ? .changed : .began,
            time: TimeInterval(event.timestamp)
        )
        
        Input.shared.mousePosition = position
        Input.shared.receiveEvent(mouseEvent)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let position = self.mousePosition(for: event)
        Input.shared.mousePosition = position
    }
    
    open override func mouseDragged(with event: NSEvent) {
        let position = self.mousePosition(for: event)
        Input.shared.mousePosition = position
    }
    
    public override func scrollWheel(with event: NSEvent) {
        
        var deltaY: CGFloat = event.scrollingDeltaY
        
        if event.hasPreciseScrollingDeltas {
            deltaY *= 0.03
        }
//
//        let mouseEvent = Input.MouseEvent(
//            button: deltaY > 0 ? .wheelUp : .wheelDown,
//            mousePosition: self.mousePosition(for: event),
//            phase: self.inputPhase(from: event.phase),
//            time: TimeInterval(event.timestamp)
//        )
        
//        Input.shared.receiveEvent(mouseEvent)
    }
    
    public override func keyUp(with event: NSEvent) {
        guard let keyCode = KeyCode(rawValue: event.charactersIgnoringModifiers ?? "") ?? KeyCode(keyCode: event.keyCode) else {
            return
        }
        
        let modifers = KeyModifier(modifiers: event.modifierFlags)
        
        let keyEvent = KeyEvent(
            window: self.windowID,
            keyCode: keyCode,
            modifiers: modifers,
            status: .up,
            time: TimeInterval(event.timestamp)
        )
        
        Input.shared.receiveEvent(keyEvent)
    }
    
    public override func keyDown(with event: NSEvent) {
        guard let keyCode = KeyCode(rawValue: event.charactersIgnoringModifiers ?? "") ?? KeyCode(keyCode: event.keyCode) else {
            return
        }
        
        let modifers = KeyModifier(modifiers: event.modifierFlags)
        
        let keyEvent = KeyEvent(
            window: self.windowID,
            keyCode: keyCode,
            modifiers: modifers,
            status: .down,
            time: TimeInterval(event.timestamp)
        )
        
        Input.shared.receiveEvent(keyEvent)
    }
    
    // MARK: - Private
    
    @discardableResult
    private func mousePosition(for event: NSEvent) -> Vector2 {
        let x = Float(event.locationInWindow.x)
        let y = Float(self.frame.size.height - event.locationInWindow.y)
        
        let position = Point(x, y)
        
        return position
    }
    
    private func inputPhase(from phase: NSEventPhase) -> MouseEvent.Phase {
        switch phase {
        case NSEventPhaseBegan: return .began
        case NSEventPhaseCancelled: return .cancelled
        case NSEventPhaseEnded: return .ended
        case NSEventPhaseChanged: return .changed
        default:
            return .ended
        }
    }

}

#endif
