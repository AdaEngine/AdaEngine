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

/// A type that represents the structure and behavior of an app.
/// - Tag: App
public protocol App {
    /// Creates an instance of the app using the body that you define for its content.
    init()
    
    associatedtype Content: AppScene
    
    /// Main scene in your app.
    var scene: Content { get }
}

public extension App {
    
    init() {
        self.init()
    }
    
    // Initializes and runs the app.
    static func main() throws {
        var application: Application!
        
        let argc = CommandLine.argc
        let argv = CommandLine.unsafeArgv
        
        try ResourceManager.initialize()
        
        let app = Self.init()
        
#if os(macOS)
        application = try MacApplication(argc: argc, argv: argv)
#endif
        
#if os(iOS) || os(tvOS)
        application = try iOSApplication(argc: argc, argv: argv)
#endif
        
#if os(Android)
        application = try AndroidApplication(argc: argc, argv: argv)
#endif
        
#if os(Linux)
        application = try LinuxApplication(argc: argc, argv: argv)
#endif
        
        guard let appScene = app.scene as? InternalAppScene else {
            fatalError("Incorrect object of App Scene")
        }
        
        var configuration = _AppSceneConfiguration()
        appScene._buildConfiguration(&configuration)
        let window = try appScene._makeWindow(with: configuration)
        
        if configuration.useDefaultRenderPlugins {
            application.renderWorld.addPlugin(DefaultRenderPlugin())
        }
        
        for plugin in configuration.plugins {
            application.renderWorld.addPlugin(plugin)
        }
        
        window.showWindow(makeFocused: true)
        
        try application.run()
    }
}
