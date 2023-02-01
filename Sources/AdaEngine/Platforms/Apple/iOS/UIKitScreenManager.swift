//
//  UIKitScreenManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/27/23.
//

#if IOS || TVOS
import UIKit

class UIKitScreenManager: ScreenManager {
    
    override func getMainScreen() -> Screen? {
        return makeScreen(from: UIScreen.main)
    }
    
    override func getScreens() -> [Screen] {
        UIScreen.screens.map(makeScreen(from:))
    }
    
    override func getSize(for screen: Screen) -> Size {
        return (screen.systemScreen as? UIScreen)?.bounds.toEngineRect.size ?? .zero
    }
    
    override func getScreenScale(for screen: Screen) -> Float {
        let scale = Float((screen.systemScreen as? UIScreen)?.nativeScale ?? 0)
        return max(1.0, scale)
    }
    
    override func makeScreen(from systemScreen: SystemScreen) -> Screen {
        Screen(systemScreen: systemScreen as! UIScreen)
    }
    
    override func getBrightness(for screen: Screen) -> Float {
        Float((screen.systemScreen as? UIScreen)?.brightness ?? 0)
    }
}

extension UIScreen: NativeScreen {}
#endif
