//
//  ScreenManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/27/23.
//

class ScreenManager {
    
    static let shared: ScreenManager = {
#if MACOS
        return MacOSScreenManager()
#elseif IOS || TVOS
        return UIKitScreenManager()
#else
        fatalErrorMethodNotImplemented()
#endif
    }()
    
    func getMainScreen() -> Screen? {
        fatalErrorMethodNotImplemented()
    }
    
    func getScreens() -> [Screen] {
        fatalErrorMethodNotImplemented()
    }
    
    func getScreenScale(for screen: Screen) -> Float {
        fatalErrorMethodNotImplemented()
    }
    
    func getSize(for screen: Screen) -> Size {
        fatalErrorMethodNotImplemented()
    }
    
    func getBrightness(for screen: Screen) -> Float {
        fatalErrorMethodNotImplemented()
    }
    
    func makeScreen(from systemScreen: SystemScreen) -> Screen {
        fatalErrorMethodNotImplemented()
    }
}
