//
//  AppleWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

#if canImport(MetalKit)
import MetalKit
@_spi(Internal) import AdaEngine

/// Because we don't have windows, this object is blank and using only for avoid crashes when windows will change their states.
final class AppleWindowManager: UIWindowManager {
    
    weak var nativeView: MetalView?
    
    override required init() { }
    
    override func resizeWindow(_ window: UIWindow, size: Size) {
        
    }
    
    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {
        
    }
    
    override func closeWindow(_ window: UIWindow) {
        
    }
    
    override func showWindow(_ window: UIWindow, isFocused: Bool) {
        
    }
    
    override func setMinimumSize(_ size: Size, for window: UIWindow) {
        
    }
    
    override func updateCursor() {
        
    }
    
    override func getScreen(for window: UIWindow) -> Screen? {
        guard let nativeScreen = nativeView?.window?.screen else {
            return nil
        }
        
        return Screen(systemScreen: nativeScreen)
    }
}

#endif
