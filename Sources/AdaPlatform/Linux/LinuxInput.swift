#if os(Linux)
    import AdaECS
    @_spi(Internal) import AdaInput
    @_spi(Internal) import AdaUI
    import AdaUtils
    import Foundation
    import Math
    import X11

    @MainActor
    final class LinuxInput {
        private var pressedKeys: [UIWindow.ID: [UInt32: AdaInput.KeyCode]] = [:]
        private var pressedButtons: [UIWindow.ID: Set<MouseButton>] = [:]

        func receive(_ event: inout XEvent, for window: UIWindow, native: LinuxSystemWindow, inputRef: Ref<Input>?) {
            guard let inputRef else {
                return
            }
            switch event.type {
            case KeyPress, KeyRelease:
                let down = event.type == KeyPress
                let symbol = unsafe XkbKeycodeToKeysym(native.display.pointer, UInt8(event.xkey.keycode), 0, 0)
                let key = Self.keyCode(for: UInt(symbol))
                let modifiers = Self.modifiers(for: event.xkey.state)
                let repeated = pressedKeys[window.id]?[event.xkey.keycode] != nil
                if down {
                    pressedKeys[window.id, default: [:]][event.xkey.keycode] = key
                } else {
                    pressedKeys[window.id]?[event.xkey.keycode] = nil
                }
                inputRef.wrappedValue.receiveEvent(
                    KeyEvent(
                        window: window.id,
                        keyCode: key,
                        modifiers: modifiers,
                        status: down ? .down : .up,
                        time: Float(Time.absolute),
                        isRepeated: down && repeated
                    )
                )
                if down, !modifiers.contains(.control), !modifiers.contains(.main) {
                    let text = lookupText(event: &event.xkey, context: native.inputContext)
                    if key == .backspace {
                        inputRef.wrappedValue.receiveEvent(TextInputEvent(window: window.id, text: "", action: .deleteBackward, time: Float(Time.absolute)))
                    } else if !text.isEmpty, !text.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) {
                        inputRef.wrappedValue.receiveEvent(TextInputEvent(window: window.id, text: text, action: .insert, time: Float(Time.absolute)))
                    }
                }
            case ButtonPress, ButtonRelease:
                let button = event.xbutton.button
                let position = Point(x: Float(event.xbutton.x), y: Float(event.xbutton.y))
                inputRef.wrappedValue.mousePosition = position
                if (4...7).contains(button) {
                    guard event.type == ButtonPress else {
                        return
                    }
                    let delta = Point(x: button == 6 ? -1 : (button == 7 ? 1 : 0), y: button == 4 ? 1 : (button == 5 ? -1 : 0))
                    inputRef.wrappedValue.receiveEvent(
                        MouseEvent(
                            window: window.id,
                            button: .scrollWheel,
                            scrollDelta: delta,
                            mousePosition: position,
                            phase: .changed,
                            modifierKeys: Self.modifiers(for: event.xbutton.state),
                            time: Float(Time.absolute)
                        )
                    )
                } else {
                    let mapped = Self.mouseButton(for: button)
                    if event.type == ButtonPress { pressedButtons[window.id, default: []].insert(mapped) } else { pressedButtons[window.id]?.remove(mapped) }
                    inputRef.wrappedValue.receiveEvent(
                        MouseEvent(
                            window: window.id,
                            button: mapped,
                            mousePosition: position,
                            phase: event.type == ButtonPress ? .began : .ended,
                            modifierKeys: Self.modifiers(for: event.xbutton.state),
                            time: Float(Time.absolute)
                        )
                    )
                }
            case MotionNotify:
                let position = Point(x: Float(event.xmotion.x), y: Float(event.xmotion.y))
                inputRef.wrappedValue.mousePosition = position
                let state = event.xmotion.state
                let button: MouseButton =
                    state & UInt32(Button1Mask) != 0
                    ? .left
                    : (state & UInt32(Button3Mask) != 0 ? .right : (state & UInt32(Button2Mask) != 0 ? .middle : .none))
                inputRef.wrappedValue.receiveEvent(
                    MouseEvent(
                        window: window.id,
                        button: button,
                        mousePosition: position,
                        phase: .changed,
                        modifierKeys: Self.modifiers(for: state),
                        time: Float(Time.absolute)
                    )
                )
            default: break
            }
        }

        func releaseAll(for window: UIWindow, inputRef: Ref<Input>?) {
            defer {
                pressedKeys[window.id] = nil
                pressedButtons[window.id] = nil
            }
            guard let inputRef else {
                return
            }
            for key in pressedKeys[window.id, default: [:]].values {
                inputRef.wrappedValue.receiveEvent(KeyEvent(window: window.id, keyCode: key, modifiers: [], status: .up, time: Float(Time.absolute), isRepeated: false))
            }
            for button in pressedButtons[window.id, default: []] {
                inputRef.wrappedValue.receiveEvent(
                    MouseEvent(
                        window: window.id,
                        button: button,
                        mousePosition: inputRef.wrappedValue.mousePosition,
                        phase: .cancelled,
                        modifierKeys: [],
                        time: Float(Time.absolute)
                    )
                )
            }
        }

        private func lookupText(event: inout XKeyEvent, context: XIC?) -> String {
            var buffer = [CChar](repeating: 0, count: 64)
            var symbol: KeySym = 0
            var status: Int32 = 0
            if let context {
                var count = unsafe Xutf8LookupString(context, &event, &buffer, Int32(buffer.count), &symbol, &status)
                if status == XBufferOverflow, count > 0 {
                    buffer = [CChar](repeating: 0, count: Int(count) + 1)
                    count = unsafe Xutf8LookupString(context, &event, &buffer, Int32(buffer.count), &symbol, &status)
                }
                guard status == XLookupChars || status == XLookupBoth, count > 0, count <= buffer.count else {
                    return ""
                }
                return String(bytes: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
            }
            let count = unsafe XLookupString(&event, &buffer, Int32(buffer.count), &symbol, nil)
            guard count > 0, count <= buffer.count else {
                return ""
            }
            return String(bytes: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
        }

        static func modifiers(for state: UInt32) -> KeyModifier {
            var modifiers: KeyModifier = []
            if state & UInt32(ShiftMask) != 0 { modifiers.insert(.shift) }
            if state & UInt32(ControlMask) != 0 { modifiers.insert(.control) }
            if state & UInt32(Mod1Mask) != 0 { modifiers.insert(.alt) }
            if state & UInt32(Mod4Mask) != 0 { modifiers.insert(.main) }
            if state & UInt32(LockMask) != 0 { modifiers.insert(.capsLock) }
            return modifiers
        }

        static func mouseButton(for button: UInt32) -> MouseButton {
            switch button {
            case 1: .left
            case 2: .middle
            case 3: .right
            default: .none
            }
        }

        static func keyCode(for symbol: UInt) -> AdaInput.KeyCode {
            switch symbol {
            case UInt(XK_Return), UInt(XK_KP_Enter): return .enter
            case UInt(XK_Escape): return .escape
            case UInt(XK_BackSpace): return .backspace
            case UInt(XK_Tab), UInt(XK_ISO_Left_Tab): return .tab
            case UInt(XK_Delete), UInt(XK_KP_Delete): return .delete
            case UInt(XK_Insert), UInt(XK_KP_Insert): return .insert
            case UInt(XK_Home), UInt(XK_KP_Home): return .home
            case UInt(XK_Page_Up), UInt(XK_KP_Page_Up): return .pageUp
            case UInt(XK_Page_Down), UInt(XK_KP_Page_Down): return .pageDown
            case UInt(XK_Left), UInt(XK_KP_Left): return .arrowLeft
            case UInt(XK_Right), UInt(XK_KP_Right): return .arrowRight
            case UInt(XK_Up), UInt(XK_KP_Up): return .arrowUp
            case UInt(XK_Down), UInt(XK_KP_Down): return .arrowDown
            case UInt(XK_Shift_L), UInt(XK_Shift_R): return .shift
            case UInt(XK_Control_L), UInt(XK_Control_R): return .ctrl
            case UInt(XK_Alt_L), UInt(XK_Alt_R): return .alt
            case UInt(XK_Super_L), UInt(XK_Super_R): return .meta
            case UInt(XK_Caps_Lock): return .capslock
            case UInt(XK_F1)...UInt(XK_F20): return AdaInput.KeyCode(rawValue: "F\(symbol - UInt(XK_F1) + 1)") ?? .none
            default:
                guard symbol >= 32, symbol < 127, let scalar = UnicodeScalar(UInt32(symbol)) else {
                    return .none
                }
                return AdaInput.KeyCode(rawValue: String(scalar).lowercased()) ?? .none
            }
        }

        static func cursorFont(for shape: Input.CursorShape) -> UInt32 {
            switch shape {
            case .arrow: UInt32(XC_left_ptr)
            case .pointingHand: UInt32(XC_hand2)
            case .iBeam: UInt32(XC_xterm)
            case .wait, .busy: UInt32(XC_watch)
            case .cross: UInt32(XC_crosshair)
            case .drag, .drop, .move: UInt32(XC_fleur)
            case .resizeLeft, .resizeRight, .resizeLeftRight: UInt32(XC_sb_h_double_arrow)
            case .resizeUp, .resizeDown, .resizeUpDown: UInt32(XC_sb_v_double_arrow)
            case .forbidden: UInt32(XC_X_cursor)
            case .help: UInt32(XC_question_arrow)
            }
        }
    }
#endif
