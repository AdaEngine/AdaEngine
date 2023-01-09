//
//  File.swift
//  
//
//  Created by v.prusakov on 1/9/23.
//

#if canImport(MetalKit)
import AdaEngine

/// Because we don't have windows, this object is blank and using only for avoid crashes when windows will change their states.
class AppleWindowManager: WindowManager {
    
    override init() { }
    
    override func resizeWindow(_ window: Window, size: Size) {
        
    }
    
    override func setWindowMode(_ window: Window, mode: Window.Mode) {
        
    }
    
    override func closeWindow(_ window: Window) {
        
    }
    
    override func showWindow(_ window: Window, isFocused: Bool) {
        
    }
}

#endif
