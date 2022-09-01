//
//  File.swift
//  
//
//  Created by v.prusakov on 9/2/22.
//

#if LINUX
import Foundation
import X11

final class LinuxWindowManager: WindowManager {
    
    override func createWindow(for window: Window) {
        fatalErrorMethodNotImplemented()
    }
    
}

#endif
