//
//  Screen.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/26/23.
//

import Math

/// An object represents user physical display.
public final class Screen {

    private unowned let screenManager: any ScreenManager

    /// Returns scale factor of the screen.
    public var scale: Float {
        return screenManager.getScreenScale(for: self)
    }
    
    /// Returns physical size of the screen.
    public var size: Size {
        screenManager.getSize(for: self)
    }
    
    /// Return current brightness of the screen.
    public var brightness: Float {
        return screenManager.getBrightness(for: self)
    }
    
    /// Contains reference to native screen.
    public private(set) weak var systemScreen: SystemScreen?

    @_spi(Internal)
    public init(systemScreen: SystemScreen, screenManager: any ScreenManager) {
        self.systemScreen = systemScreen
        self.screenManager = screenManager
    }
}

extension Screen {
    package static nonisolated(unsafe) var screenManager: (any ScreenManager)!

    /// Returns the screen object containing the window with the keyboard focus.
    /// - Returns: Returns the main sreen or nil if we run in headless mode.
    public static var main: Screen? {
        return unsafe screenManager.getMainScreen()
    }

    /// Returns list of available screens.
    public static var screens: [Screen] {
        unsafe screenManager.getScreens()
    }
}

/// Represents platform specific screen.
public protocol SystemScreen: AnyObject {}
