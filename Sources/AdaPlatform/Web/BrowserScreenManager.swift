//
//  BrowserScreenManager.swift
//  AdaEngine
//

#if WASM && canImport(JavaScriptKit)
@_spi(Internal) import AdaUI
import JavaScriptKit
import Math

final class BrowserScreenManager: ScreenManager, @unchecked Sendable {
    private let browserScreen = BrowserSystemScreen()

    func getMainScreen() -> Screen? {
        makeScreen(from: browserScreen)
    }

    func getScreens() -> [Screen] {
        [makeScreen(from: browserScreen)]
    }

    func getScreenScale(for screen: Screen) -> Float {
        Float(JSObject.global.window.devicePixelRatio.number ?? 1)
    }

    func getSize(for screen: Screen) -> Size {
        let window = JSObject.global.window
        return Size(
            width: Float(window.innerWidth.number ?? 0),
            height: Float(window.innerHeight.number ?? 0)
        )
    }

    func getBrightness(for screen: Screen) -> Float {
        1
    }

    func makeScreen(from systemScreen: SystemScreen) -> Screen {
        Screen(systemScreen: systemScreen, screenManager: self)
    }
}

final class BrowserSystemScreen: SystemScreen {}
#endif
