//
//  ApplicationCreate.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

import Foundation

/// Create application instance
@discardableResult
public func ApplicationCreate(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    do {
        var application: Application!
        
        #if os(macOS)
        application = try MacApplication(argc: argc, argv: argv)
        #endif
        
        Application.shared = application
        
        try application.run()
        
        return EXIT_SUCCESS
    } catch {
        return EXIT_FAILURE
    }
}
