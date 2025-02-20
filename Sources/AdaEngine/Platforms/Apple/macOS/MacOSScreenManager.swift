//
//  MacOSScreenManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/27/23.
//

#if MACOS

import AppKit
import IOKit

class MacOSScreenManager: ScreenManager {
    
    override func getScreens() -> [Screen] {
        return NSScreen.screens.map(makeScreen(from:))
    }
    
    override func getMainScreen() -> Screen? {
        return NSScreen.main.flatMap(makeScreen(from:))
    }
    
    override func makeScreen(from systemScreen: SystemScreen) -> Screen {
        Screen(systemScreen: systemScreen as! NSScreen)
    }
    
    override func getSize(for screen: Screen) -> Size {
        return (screen.systemScreen as? NSScreen)?.frame.toEngineRect.size ?? .zero
    }
    
    override func getScreenScale(for screen: Screen) -> Float {
        let scale = Float((screen.systemScreen as? NSScreen)?.backingScaleFactor ?? 0.0)
        return max(1.0, scale)
    }
    
    // FIXME: Currently returns birghtness for first screen
    override func getBrightness(for screen: Screen) -> Float {
        var iterator: io_iterator_t = 0
        var service: io_object_t = 1
        var brighntess: Float = 1.0
        
        let dict: CFDictionary = IOServiceMatching("IODisplayConnect")!
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, dict, &iterator)
        if result == KERN_SUCCESS {
            while service != 0 {
                service = IOIteratorNext(iterator)
                IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brighntess)
                IOObjectRelease(service)
            }
        }
        
        return brighntess
    }
}

@_spi(Internal)
extension NSScreen: SystemScreen {}

#endif
