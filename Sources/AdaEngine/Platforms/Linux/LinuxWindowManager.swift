//
//  LinuxWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/2/22.
//

#if LINUX
import X11.Xlib
import X11.X


final class LinuxWindowManager: WindowManager {
    
    override func createWindow(for window: Window) {
        fatalErrorMethodNotImplemented()
    }
    
}

#endif
