//
//  Screen.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/26/23.
//

import Math

/// An object represents user physical display.
public final class Screen {
    
    /// Returns the screen object containing the window with the keyboard focus.
    /// - Returns: Returns the main sreen or nil if we run in headless mode.
    public static var main: Screen? {
        return nil
//        ScreenManager.shared.getMainScreen()
    }
    
    /// Returns list of available screens.
    public static var screens: [Screen] {
        []
//        ScreenManager.shared.getScreens()
    }
    
    /// Returns scale factor of the screen.
    public var scale: Float {
        return 1
//        ScreenManager.shared.getScreenScale(for: self)
    }
    
    /// Returns physical size of the screen.
    public var size: Size {
        return .zero
//        ScreenManager.shared.getSize(for: self)
    }
    
    /// Return current brightness of the screen.
    public var brightness: Float {
        return 1
//        ScreenManager.shared.getBrightness(for: self)
    }
    
    /// Contains reference to native screen.
    public private(set) weak var systemScreen: SystemScreen?

    @_spi(Internal)
    public init(systemScreen: SystemScreen) {
        self.systemScreen = systemScreen
    }
}

/// Represents platform specific screen.
public protocol SystemScreen: AnyObject {}
