#if os(Android)
    import AdaApp
    import AdaInput
    import CAndroid
    import Foundation

    /// Starts an AdaEngine app inside Android's NativeActivity.
    ///
    /// Export `ada_android_start` from a dynamic Swift library and call this method
    /// with an app factory. The native host installs the Swift custom main executor on the
    /// Android main looper before invoking the entry point.
    @MainActor
    public enum AndroidRuntime {
        static var textInputSession = TextInputEvent.Session()

        private static var task: Task<Void, Never>?

        /// Optional native host integration for AdaUI's software keyboard focus.
        public static var textInputFocusChanged: (@MainActor (Bool) -> Void)?

        static func updateTextInputFocus(_ focused: Bool) {
            textInputSession.invalidate()
            textInputSession = TextInputEvent.Session()
            textInputFocusChanged?(focused)
        }

        /// Refreshes host services when a paused or recreated activity resumes.
        public static var didResume: (@MainActor () -> Void)?

        /// Return true after handling Android Back inside the app's navigation.
        /// Returning false finishes the native activity.
        public static var backRequested: (@MainActor () -> Bool)?

        /// Routes a native Back gesture through the app before finishing its activity.
        public static func requestBack() {
            if backRequested?() != true { unsafe ada_android_finish() }
        }

        /// Delivers committed IME text to the focused AdaUI control.
        public static func insertText(_ text: String, deleteBackward: Bool = false) {
            (Application.shared as? AndroidApplication)?.insertText(text, deleteBackward: deleteBackward)
        }

        /// Delivers an operation from a full Android InputConnection.
        public static func inputText(_ text: String, action: TextInputEvent.Action, cursorOffset: Int = 1, rangeStart: Int = 0, rangeEnd: Int = 0) {
            (Application.shared as? AndroidApplication)?.inputText(text, action: action, cursorOffset: cursorOffset, rangeStart: rangeStart, rangeEnd: rangeEnd)
        }

        /// Updates AdaUI's keyboard avoidance from the native IME inset, in pixels.
        public static func setKeyboardOccludedHeight(_ height: Float) {
            (Application.shared as? AndroidApplication)?.setKeyboardOccludedHeight(height)
        }

        /// Updates physical system-bar and cutout insets reported by a native host, in pixels.
        public static func setSafeAreaInsets(top: Float, leading: Float, bottom: Float, trailing: Float) {
            (Application.shared as? AndroidApplication)?.setSafeAreaInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        }

        /// Writes a native Android logcat message under the AdaEngine tag.
        public nonisolated static func log(_ message: String) {
            unsafe message.withCString { unsafe ada_android_log($0) }
        }

        public nonisolated static func start<A: App>(_ factory: @escaping @MainActor @Sendable () -> A) {
            Task { @MainActor in
                guard task == nil else { return }
                task = Task { @MainActor in
                    do {
                        try await AppRuntime.run(factory())
                    } catch {
                        log("Android app failed: \(error)")
                        unsafe ada_android_finish()
                    }
                }
            }
        }

    }

    @_cdecl("ada_android_frame")
    func androidFrame(_ time: Int64) {
        Task { @MainActor in
            (Application.shared as? AndroidApplication)?.frame(time)
        }
    }

    @_cdecl("ada_android_surface_changed")
    func androidSurfaceChanged(_ width: Int32, _ height: Int32, _ scale: Float) {
        Task { @MainActor in
            (Application.shared as? AndroidApplication)?.resize(width: width, height: height, scale: scale)
        }
    }

    @_cdecl("ada_android_surface_lost")
    func androidSurfaceLost() {
        Task { @MainActor in
            (Application.shared as? AndroidApplication)?.detachSurface()
        }
    }

    @_cdecl("ada_android_state")
    func androidState(_ state: Int32) {
        Task { @MainActor in
            guard let app = Application.shared as? AndroidApplication else { return }
            // Android may recreate NativeActivity inside the same process. Keep
            // the single app context suspended and resume it with the new surface.
            app.setResumed(state == 1)
            if state == 1 { AndroidRuntime.didResume?() }
        }
    }

    @_cdecl("ada_android_touch")
    func androidTouch(_ id: Int32, _ phase: Int32, _ x: Float, _ y: Float) {
        Task { @MainActor in
            (Application.shared as? AndroidApplication)?.touch(id: id, phase: phase, x: x, y: y)
        }
    }

    @_cdecl("ada_android_back")
    func androidBack() {
        Task { @MainActor in
            AndroidRuntime.requestBack()
        }
    }
#endif
