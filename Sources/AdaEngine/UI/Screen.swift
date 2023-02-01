//
//  Screen.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/26/23.
//

/// The object represents display.
public final class Screen {
    
    /// Returns the screen object containing the window with the keyboard focus.
    /// - Returns: Returns the main sreen or nil if we run in headless mode.
    public static var main: Screen? {
        ScreenManager.shared.getMainScreen()
    }
    
    public static var screens: [Screen] {
        ScreenManager.shared.getScreens()
    }
    
    public var scale: Float {
        ScreenManager.shared.getScreenScale(for: self)
    }
    
    public var size: Size {
        ScreenManager.shared.getSize(for: self)
    }
    
    public var brightness: Float {
        ScreenManager.shared.getBrightness(for: self)
    }
    
    /// Contains reference to native screen.
    internal private(set) weak var systemScreen: SystemScreen?
    
    init(systemScreen: SystemScreen) {
        self.systemScreen = systemScreen
    }
    
}

protocol SystemScreen: AnyObject {}
