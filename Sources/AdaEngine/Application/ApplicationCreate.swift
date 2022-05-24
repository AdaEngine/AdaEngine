//
//  ApplicationCreate.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public struct ApplicationRunOptions {
    public var initialScene: Scene?
    
    public init(initialScene: Scene? = nil) {
        self.initialScene = initialScene
    }
}

/// Create application instance
@discardableResult
public func ApplicationCreate(
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>,
    options: ApplicationRunOptions = ApplicationRunOptions()) -> Int32 {
    do {
        var application: Application!
        
        #if os(macOS)
        application = try MacApplication(argc: argc, argv: argv)
        #endif
        
        #if os(iOS) || os(tvOS)
        application = try iOSApplication(argc: argc, argv: argv)
        #endif
        
        Application.shared = application
        
        if let scene = options.initialScene {
            Engine.shared.setRootScene(scene)
        }
        
        try application.run(options: options)
        
        return EXIT_SUCCESS
    } catch {
        return EXIT_FAILURE
    }
}
