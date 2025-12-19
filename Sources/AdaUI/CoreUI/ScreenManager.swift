//
//  ScreenManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/27/23.
//

import AdaUtils
import Math

open class ScreenManager {
    open func getMainScreen() -> Screen? {
        fatalErrorMethodNotImplemented()
    }
    
    open func getScreens() -> [Screen] {
        fatalErrorMethodNotImplemented()
    }
    
    open func getScreenScale(for screen: Screen) -> Float {
        fatalErrorMethodNotImplemented()
    }
    
    open func getSize(for screen: Screen) -> Size {
        fatalErrorMethodNotImplemented()
    }
    
    open func getBrightness(for screen: Screen) -> Float {
        fatalErrorMethodNotImplemented()
    }
    
    open func makeScreen(from systemScreen: SystemScreen) -> Screen {
        fatalErrorMethodNotImplemented()
    }
}
