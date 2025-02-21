//
//  Screen.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/26/23.
//

/// An object represents user physical display.
public final class Screen {
    
    /// Returns the screen object containing the window with the keyboard focus.
    /// - Returns: Returns the main sreen or nil if we run in headless mode.
    public static var main: Screen? {
        ScreenManager.shared.getMainScreen()
    }
    
    /// Returns list of available screens.
    public static var screens: [Screen] {
        ScreenManager.shared.getScreens()
    }
    
    /// Returns scale factor of the screen.
    public var scale: Float {
        ScreenManager.shared.getScreenScale(for: self)
    }
    
    /// Returns physical size of the screen.
    public var size: Size {
        ScreenManager.shared.getSize(for: self)
    }
    
    /// Return current brightness of the screen.
    public var brightness: Float {
        ScreenManager.shared.getBrightness(for: self)
    }
    
    /// Contains reference to native screen.
    internal private(set) weak var systemScreen: SystemScreen?
    
    @_spi(Internal)
    public init(systemScreen: SystemScreen) {
        self.systemScreen = systemScreen
    }
}

/// Represents platform specific screen.
@_spi(Internal)
public protocol SystemScreen: AnyObject {}
