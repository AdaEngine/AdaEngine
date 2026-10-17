#if os(Linux)
    @_spi(Internal) import AdaUI
    import Math
    import X11

    /// Immutable primary-screen snapshot; safe to read from layout and render workers.
    final class LinuxScreenManager: ScreenManager {
        private let systemScreen = LinuxSystemScreen()
        private let size: Size

        @MainActor
        init(display: LinuxDisplay) {
            let screen = unsafe XDefaultScreen(display.pointer)
            size = unsafe Size(
                width: Float(XDisplayWidth(display.pointer, screen)),
                height: Float(XDisplayHeight(display.pointer, screen))
            )
        }

        func getMainScreen() -> AdaUI.Screen? { makeScreen(from: systemScreen) }
        func getScreens() -> [AdaUI.Screen] { [makeScreen(from: systemScreen)] }
        func getScreenScale(for _: AdaUI.Screen) -> Float { 1 }
        func getSize(for _: AdaUI.Screen) -> Size { size }
        func getBrightness(for _: AdaUI.Screen) -> Float { 1 }
        func makeScreen(from systemScreen: SystemScreen) -> AdaUI.Screen { AdaUI.Screen(systemScreen: systemScreen, screenManager: self) }
    }

    private final class LinuxSystemScreen: SystemScreen {}
#endif
