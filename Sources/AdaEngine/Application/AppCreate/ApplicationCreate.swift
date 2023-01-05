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
        
        let app = Self.init()
        
#if os(macOS)
        application = try MacApplication(argc: argc, argv: argv)
#endif
        
#if os(iOS) || os(tvOS)
        application = try iOSApplication(argc: argc, argv: argv)
#endif
        
        Application.shared = application
        
        let appScene = app.scene
        let configuration = appScene._configuration
        
        let window = try appScene._makeWindow(with: configuration)
        
        window.showWindow(makeFocused: true)
        
        try application.run()
    }
}
