#if os(Linux)
    import AdaECS
    @_spi(Internal) @testable import AdaInput
    @testable import AdaPlatform
    @_spi(Internal) @testable import AdaRender
    @_spi(Internal) import AdaUI
    import AdaUtils
    import Foundation
    import Math
    import Testing
    import X11

    @Suite("Linux platform", .serialized)
    @MainActor
    struct LinuxPlatformTests {
        @Test func mapsKeyboardAndPointer() {
            #expect(LinuxInput.keyCode(for: UInt(XK_a)) == .a)
            #expect(LinuxInput.keyCode(for: UInt(XK_Left)) == .arrowLeft)
            #expect(LinuxInput.keyCode(for: UInt(XK_F12)) == .f12)
            #expect(LinuxInput.keyCode(for: UInt(XK_Control_R)) == .ctrl)
            #expect(LinuxInput.mouseButton(for: 2) == .middle)
            #expect(LinuxInput.mouseButton(for: 3) == .right)
            #expect(LinuxInput.modifiers(for: UInt32(ShiftMask | ControlMask | Mod1Mask | Mod4Mask | LockMask)) == [.shift, .control, .alt, .main, .capsLock])
        }

        @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_LINUX_WINDOW_TESTS"] == "1"))
        func nativeWindowLifecycle() async throws {
            try RenderEngine.setupRenderEngine()
            let display = try LinuxDisplay()
            let manager = LinuxWindowManager(display: display)
            let window = UIWindow(
                frame: Rect(x: 10, y: 10, width: 640, height: 480),
                configuration: .init(title: "AdaEngine Linux Test", minimumSize: Size(width: 100, height: 100)),
                windowManager: manager
            )
            let native = try #require(window.systemWindow as? LinuxSystemWindow)
            let world = World()
            world.insertResource(Input(gameControllerEngine: nil))
            let input = world.getRefResource(Input.self)
            manager.inputRef = input
            #expect(manager.windows[window.id] === window)
            #expect(native.xlibWindow != 0)
            window.showWindow(makeFocused: false)
            window.frame.size = Size(width: 700, height: 500)
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(2))
            repeat {
                unsafe XSync(display.pointer, 0)
                manager.pollEvents()
                if native.size == Size(width: 700, height: 500), unsafe RenderEngine.shared.getRenderWindow(for: window.id)?.width == 700 {
                    break
                }
                try await Task.sleep(for: .milliseconds(10))
            } while clock.now < deadline
            #expect(native.size == Size(width: 700, height: 500))
            #expect(window.frame.size == native.size)
            #expect(unsafe RenderEngine.shared.getRenderWindow(for: window.id)?.width == 700)

            var key = XEvent()
            key.xkey.type = KeyPress
            key.xkey.display = display.pointer
            key.xkey.window = native.handle
            key.xkey.root = unsafe XDefaultRootWindow(display.pointer)
            key.xkey.keycode = unsafe UInt32(XKeysymToKeycode(display.pointer, UInt(XK_a)))
            key.xkey.same_screen = 1
            unsafe XSendEvent(display.pointer, native.handle, 0, KeyPressMask, &key)
            unsafe XSync(display.pointer, 0)
            manager.pollEvents()
            input.wrappedValue.flushPendingEvents()
            #expect(input.wrappedValue.getInputEvents().contains { ($0 as? KeyEvent)?.keyCode == .a })
            #expect(input.wrappedValue.getTextInputEvents().contains { $0.text == "a" })

            var focus = XEvent()
            focus.xfocus.type = FocusOut
            focus.xfocus.display = display.pointer
            focus.xfocus.window = native.handle
            focus.xfocus.mode = NotifyNormal
            focus.xfocus.detail = NotifyNonlinear
            unsafe XSendEvent(display.pointer, native.handle, 0, FocusChangeMask, &focus)
            unsafe XSync(display.pointer, 0)
            manager.pollEvents()
            input.wrappedValue.flushPendingEvents()
            #expect(input.wrappedValue.getInputEvents().contains { ($0 as? KeyEvent)?.status == .up })
            var close = XEvent()
            close.xclient.type = ClientMessage
            close.xclient.window = native.handle
            close.xclient.message_type = unsafe XInternAtom(display.pointer, "WM_PROTOCOLS", 0)
            close.xclient.format = 32
            close.xclient.data.l.0 = unsafe Int(XInternAtom(display.pointer, "WM_DELETE_WINDOW", 0))
            unsafe XSendEvent(display.pointer, native.handle, 0, 0, &close)
            unsafe XSync(display.pointer, 0)
            manager.pollEvents()
            #expect(manager.windows.isEmpty)
            #expect(window.systemWindow == nil)
            #expect(native.xlibWindow == 0)
        }
    }
#endif
