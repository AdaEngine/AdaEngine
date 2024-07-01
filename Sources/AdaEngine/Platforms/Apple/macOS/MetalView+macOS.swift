//
//  MetalView+macOS.swift
//  AdaEngine
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
        
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect, .activeInKeyWindow]
        
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
    
    open override func cursorUpdate(with event: NSEvent) {
        Application.shared.windowManager.updateCursor()
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
        var deltaY = Float(event.scrollingDeltaY)
        var deltaX = Float(event.scrollingDeltaY)

        if event.hasPreciseScrollingDeltas {
            deltaX += 0.03
            deltaY *= 0.03
        }

        let mouseEvent = MouseEvent(
            window: self.windowID,
            button: .scrollWheel,
            scrollDelta: Point(x: deltaX, y: deltaY),
            mousePosition: self.mousePosition(for: event),
            phase: self.inputPhase(from: event.phase),
            time: TimeInterval(event.timestamp)
        )
        
        Input.shared.receiveEvent(mouseEvent)
    }
    
    public override func keyUp(with event: NSEvent) {
        let keyCode = MacOSKeyboard.shared.translateKey(from: event.keyCode)

        let modifers = KeyModifier(modifiers: event.modifierFlags)
        
        let keyEvent = KeyEvent(
            window: self.windowID,
            keyCode: keyCode,
            modifiers: modifers,
            status: .up,
            time: TimeInterval(event.timestamp),
            isRepeated: event.isARepeat
        )
        
        Input.shared.receiveEvent(keyEvent)
    }
    
    public override func keyDown(with event: NSEvent) {
        let keyCode = MacOSKeyboard.shared.translateKey(from: event.keyCode)
        let modifers = KeyModifier(modifiers: event.modifierFlags)
        
        let keyEvent = KeyEvent(
            window: self.windowID,
            keyCode: keyCode,
            modifiers: modifers,
            status: .down,
            time: TimeInterval(event.timestamp),
            isRepeated: event.isARepeat
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
    
    private func inputPhase(from phase: NSEvent.Phase) -> MouseEvent.Phase {
        switch phase {
        case .began: return .began
        case .cancelled: return .cancelled
        case .ended: return .ended
        case .changed: return .changed
        default:
            return .ended
        }
    }
}

#endif
