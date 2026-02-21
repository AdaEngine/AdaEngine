//
//  MetalView+iOS.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

#if os(iOS)
import AdaUtils
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaUI
import UIKit
import Math
import AdaECS

extension MetalView: UIKeyInput {

    public var hasText: Bool {
        // Return true to indicate that we can accept text input
        return true
    }

    public func insertText(_ text: String) {
        let textEvent = TextInputEvent(
            window: self.windowID,
            text: text,
            action: .insert,
            time: TimeInterval(CACurrentMediaTime())
        )

        input?.wrappedValue.receiveEvent(textEvent)
    }

    public func deleteBackward() {
        let textEvent = TextInputEvent(
            window: self.windowID,
            text: "",
            action: .deleteBackward,
            time: TimeInterval(CACurrentMediaTime())
        )

        input?.wrappedValue.receiveEvent(textEvent)
    }
}

extension MetalView {
    // MARK: - Input Access

    var input: Ref<Input>? {
        self.windowManager?.inputRef
    }

    // MARK: - First Responder

    open override var canBecomeFirstResponder: Bool {
        return true
    }

    public var keyboardType: UIKeyboardType {
        return .default
    }

    public var autocorrectionType: UITextAutocorrectionType {
        return .no
    }

    public var autocapitalizationType: UITextAutocapitalizationType {
        return .none
    }

    // MARK: - Touch Events

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !self.isFirstResponder {
            self.becomeFirstResponder()
        }

        for touch in touches {
            let point = touch.location(in: self)

            let touchEvent = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .began,
                time: TimeInterval(event?.timestamp ?? 0)
            )

            input?.wrappedValue.receiveEvent(touchEvent)
        }
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)

            let touchEvent = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .moved,
                time: TimeInterval(event?.timestamp ?? 0)
            )

            input?.wrappedValue.receiveEvent(touchEvent)
        }
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)

            let touchEvent = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .cancelled,
                time: TimeInterval(event?.timestamp ?? 0)
            )

            input?.wrappedValue.receiveEvent(touchEvent)
        }
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)

            let touchEvent = TouchEvent(
                window: self.windowID,
                location: Point(Float(point.x), Float(point.y)),
                phase: .ended,
                time: TimeInterval(event?.timestamp ?? 0)
            )

            input?.wrappedValue.receiveEvent(touchEvent)
        }
    }

    // MARK: - Physical Keyboard Events

       open override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
           var didHandleEvent = false

           for press in presses {
               guard let key = press.key else { continue }

               let keyCode = AppleEmbeddedKeyboard.shared.translateKey(from: key.keyCode)
               guard keyCode != .none else { continue }

               let keyEvent = KeyEvent(
                   window: self.windowID,
                   keyCode: keyCode,
                   modifiers: KeyModifier(modifiers: key.modifierFlags),
                   status: .down,
                   time: TimeInterval(event?.timestamp ?? 0),
                   isRepeated: false
               )

               input?.wrappedValue.receiveEvent(keyEvent)
               didHandleEvent = true
           }

           if !didHandleEvent {
               super.pressesBegan(presses, with: event)
           }
       }

       open override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
           // Handle key repeat events
           for press in presses {
               guard let key = press.key else { continue }

               let keyCode = AppleEmbeddedKeyboard.shared.translateKey(from: key.keyCode)
               guard keyCode != .none else { continue }

               let keyEvent = KeyEvent(
                   window: self.windowID,
                   keyCode: keyCode,
                   modifiers: KeyModifier(modifiers: key.modifierFlags),
                   status: .down,
                   time: TimeInterval(event?.timestamp ?? 0),
                   isRepeated: true
               )

               input?.wrappedValue.receiveEvent(keyEvent)
           }
       }

       open override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
           var didHandleEvent = false

           for press in presses {
               guard let key = press.key else { continue }

               let keyCode = AppleEmbeddedKeyboard.shared.translateKey(from: key.keyCode)
               guard keyCode != .none else { continue }

               let keyEvent = KeyEvent(
                   window: self.windowID,
                   keyCode: keyCode,
                   modifiers: KeyModifier(modifiers: key.modifierFlags),
                   status: .up,
                   time: TimeInterval(event?.timestamp ?? 0),
                   isRepeated: false
               )

               input?.wrappedValue.receiveEvent(keyEvent)
               didHandleEvent = true
           }

           if !didHandleEvent {
               super.pressesEnded(presses, with: event)
           }
       }

       open override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
           for press in presses {
               guard let key = press.key else { continue }

               let keyCode = AppleEmbeddedKeyboard.shared.translateKey(from: key.keyCode)
               guard keyCode != .none else { continue }

               let keyEvent = KeyEvent(
                   window: self.windowID,
                   keyCode: keyCode,
                   modifiers: KeyModifier(modifiers: key.modifierFlags),
                   status: .up,
                   time: TimeInterval(event?.timestamp ?? 0),
                   isRepeated: false
               )

               input?.wrappedValue.receiveEvent(keyEvent)
           }
       }

       // MARK: - Mouse/Trackpad Hover Events (iPadOS)

       /// Setup mouse tracking for iPadOS pointer support.
       /// Call this method after the view is added to the window.
       func setupMouseTracking() {
           let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
           self.addGestureRecognizer(hoverGesture)
       }

       @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
           let location = recognizer.location(in: self)
           let position = Point(Float(location.x), Float(location.y))

           input?.mousePosition = position

           let phase: MouseEvent.Phase
           switch recognizer.state {
           case .began:
               phase = .began
           case .changed:
               phase = .changed
           case .ended, .cancelled:
               phase = .ended
           default:
               return
           }

           let mouseEvent = MouseEvent(
               window: self.windowID,
               button: .none,
               mousePosition: position,
               phase: phase,
               modifierKeys: [],
               time: TimeInterval(CACurrentMediaTime())
           )

           input?.wrappedValue.receiveEvent(mouseEvent)
       }

       // MARK: - Coordinate Conversion

       private func mousePosition(for location: CGPoint) -> Vector2 {
           let x = Float(location.x)
           let y = Float(location.y)
           return Point(x, y)
       }
}

#endif
