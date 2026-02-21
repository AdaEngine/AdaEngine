//
//  MetalView+macOS.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

#if MACOS
import AdaUtils
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaUI
import AppKit
import Math
import AdaECS

extension MetalView {

    var input: Ref<Input>? {
        self.windowManager?.inputRef
    }

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
            modifierKeys: KeyModifier(modifiers: event.modifierFlags),
            time: TimeInterval(event.timestamp)
        )
        
        input?.mousePosition = position
        input?.wrappedValue.receiveEvent(mouseEvent)
    }
    
    open override func cursorUpdate(with event: NSEvent) {
        Application.shared.windowManager.updateCursor()
    }
    
    public override func mouseDown(with event: NSEvent) {
        if let eventWindow = event.window, eventWindow.firstResponder !== self {
            eventWindow.makeFirstResponder(self)
        }

        let position = self.mousePosition(for: event)
        
        let isContinious = input?.wrappedValue.mouseEvents[.left]?.phase == .began

        let mouseEvent = MouseEvent(
            window: self.windowID,
            button: .left,
            mousePosition: position,
            phase: isContinious ? .changed : .began,
            modifierKeys: KeyModifier(modifiers: event.modifierFlags),
            time: TimeInterval(event.timestamp)
        )
        
        input?.mousePosition = position
        input?.wrappedValue.receiveEvent(mouseEvent)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let position = self.mousePosition(for: event)
        input?.mousePosition = position

        let event = MouseEvent(
            window: self.windowID,
            button: .none,
            mousePosition: position,
            phase: .changed,
            modifierKeys: KeyModifier(modifiers: event.modifierFlags),
            time: TimeInterval(event.timestamp)
        )
        input?.wrappedValue.receiveEvent(event)
    }

    open override func mouseDragged(with event: NSEvent) {
        let position = self.mousePosition(for: event)
        input?.mousePosition = position

        let event = MouseEvent(
            window: self.windowID,
            button: .none,
            mousePosition: position,
            phase: .changed,
            modifierKeys: KeyModifier(modifiers: event.modifierFlags),
            time: TimeInterval(event.timestamp)
        )
        input?.wrappedValue.receiveEvent(event)
    }
    
    public override func scrollWheel(with event: NSEvent) {
        var deltaX = Float(event.scrollingDeltaX)
        var deltaY = Float(event.scrollingDeltaY)

        if event.hasPreciseScrollingDeltas {
            deltaX *= 0.03
            deltaY *= 0.03
        }

        let mouseEvent = MouseEvent(
            window: self.windowID,
            button: .scrollWheel,
            scrollDelta: Point(x: deltaX, y: deltaY),
            mousePosition: self.mousePosition(for: event),
            phase: self.inputPhase(from: event.phase),
            modifierKeys: KeyModifier(modifiers: event.modifierFlags),
            time: TimeInterval(event.timestamp)
        )

        input?.wrappedValue.receiveEvent(mouseEvent)
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
        
        input?.wrappedValue.receiveEvent(keyEvent)
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
        
        input?.wrappedValue.receiveEvent(keyEvent)

        if keyCode == .backspace {
            let textEvent = TextInputEvent(
                window: self.windowID,
                text: "",
                action: .deleteBackward,
                time: TimeInterval(event.timestamp)
            )
            input?.wrappedValue.receiveEvent(textEvent)
            return
        }

        guard
            let insertedText = event.characters,
            let textPayload = Self.textInputPayload(
                keyCode: keyCode,
                modifiers: modifers,
                characters: insertedText
            )
        else {
            return
        }

        let textEvent = TextInputEvent(
            window: self.windowID,
            text: textPayload,
            action: .insert,
            time: TimeInterval(event.timestamp)
        )

        input?.wrappedValue.receiveEvent(textEvent)
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

    static func textInputPayload(
        keyCode: KeyCode,
        modifiers: KeyModifier,
        characters: String
    ) -> String? {
        if modifiers.contains(.main) || modifiers.contains(.control) {
            return nil
        }

        switch keyCode {
        case .none,
             .enter,
             .tab,
             .escape,
             .delete,
             .home,
             .pageUp,
             .pageDown,
             .shift,
             .ctrl,
             .alt,
             .meta,
             .capslock,
             .arrowUp,
             .arrowDown,
             .arrowLeft,
             .arrowRight,
             .f1,
             .f2,
             .f3,
             .f4,
             .f5,
             .f6,
             .f7,
             .f8,
             .f9,
             .f10,
             .f11,
             .f12,
             .f13,
             .f14,
             .f15,
             .f16,
             .f17,
             .f18,
             .f19,
             .f20,
             .volumeDown,
             .volumeUp,
             .volumeMute:
            return nil
        default:
            break
        }

        let sanitizedText = characters
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        guard !sanitizedText.isEmpty else {
            return nil
        }

        let containsUnsupportedScalars = sanitizedText.unicodeScalars.contains { scalar in
            let value = scalar.value
            if value < 0x20 || value == 0x7F {
                return true
            }

            // AppKit function keys (arrows, home/end, etc.) live in this range.
            if (0xF700...0xF8FF).contains(value) {
                return true
            }

            return false
        }

        return containsUnsupportedScalars ? nil : sanitizedText
    }
}

#endif
