#if os(visionOS)
    import AdaEngine
    import GameController

    /// Poll keyboard state without replacing the native editor's keyboard event handlers.
    /// Mouse callbacks preserve prior handlers and are restored when immersion ends.
    @MainActor
    final class EditorVRDesktopInput {
        private struct MouseSource {
            let cursor: GCDeviceCursor
            let previous: GCControllerDirectionPadValueChangedHandler?
        }
        private var sources: [ObjectIdentifier: MouseSource] = [:]
        private var pendingWheel: Float = 0
        private var running = false
        var canScroll: (() -> Bool)?

        func start() { running = true }
        func stop() {
            running = false
            for source in sources.values { source.cursor.valueChangedHandler = source.previous }
            sources.removeAll()
            pendingWheel = 0
        }

        func sample() -> (keys: Set<KeyCode>, wheel: Float) {
            guard running else {
                return ([], 0)
            }
            let mice = GCMouse.mice().compactMap { $0.mouseInput?.scroll }
            let identifiers = Set(mice.map { ObjectIdentifier($0) })
            for id in Array(sources.keys) where !identifiers.contains(id) {
                if let source = sources.removeValue(forKey: id) { source.cursor.valueChangedHandler = source.previous }
            }
            for cursor in mice where sources[ObjectIdentifier(cursor)] == nil {
                let previous = cursor.valueChangedHandler
                sources[ObjectIdentifier(cursor)] = MouseSource(cursor: cursor, previous: previous)
                cursor.valueChangedHandler = { [weak self] pad, x, y in
                    previous?(pad, x, y)
                    Task { @MainActor [weak self] in
                        guard let self, self.running, self.canScroll?() != false else {
                            return
                        }
                        self.pendingWheel += y
                    }
                }
            }
            var keys: Set<KeyCode> = []
            if let keyboard = GCKeyboard.coalesced?.keyboardInput {
                let modified = [.leftGUI, .rightGUI, .leftControl, .rightControl, .leftAlt, .rightAlt].contains { (key: GCKeyCode) in
                    keyboard.button(forKeyCode: key)?.isPressed == true
                }
                if !modified {
                    for (code, key): (GCKeyCode, KeyCode) in [(.keyW, .w), (.keyA, .a), (.keyS, .s), (.keyD, .d)]
                    where keyboard.button(forKeyCode: code)?.isPressed == true {
                        keys.insert(key)
                    }
                }
            }
            let wheel = pendingWheel
            pendingWheel = 0
            return (keys, wheel)
        }
    }
#endif
