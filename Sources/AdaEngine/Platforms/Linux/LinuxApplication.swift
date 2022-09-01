//
//  LinuxApplication.swift
//  
//
//  Created by v.prusakov on 9/2/22.
//

#if LINUX
import Foundation
import X11

final class LinuxApplication: Application {
    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)
        
        self.windowManager = LinuxWindowManager()
    }
}

#endif
