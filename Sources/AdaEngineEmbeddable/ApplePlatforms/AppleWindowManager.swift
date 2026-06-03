//
//  AppleWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

#if canImport(MetalKit)
import MetalKit
@_spi(Internal) import AdaEngine
@_spi(Internal) import AdaPlatform

/// Because we don't have windows, this object is blank and using only for avoid crashes when windows will change their states.
final class AppleWindowManager: UIWindowManager {
    
    weak var nativeView: MetalView?
    var screenManager: ScreenManager
    
    init(screenManager: ScreenManager) {
        self.screenManager = screenManager
    }
    
    override func resizeWindow(_ window: AdaEngine.UIWindow, size: Size) {
        
    }
    
    override func setWindowMode(_ window: AdaEngine.UIWindow, mode: AdaEngine.UIWindow.Mode) {
        
    }
    
    override func closeWindow(_ window: AdaEngine.UIWindow) {
        
    }
    
    override func showWindow(_ window: AdaEngine.UIWindow, isFocused: Bool) {
        
    }
    
    override func setMinimumSize(_ size: Size, for window: AdaEngine.UIWindow) {
        
    }
    
    override func updateCursor() {
        
    }
    
    override func getScreen(for window: AdaEngine.UIWindow) -> Screen? {
        guard let nativeScreen = nativeView?.window?.screen else {
            return nil
        }
        
        return Screen(systemScreen: nativeScreen, screenManager: screenManager)
    }
}

#endif
