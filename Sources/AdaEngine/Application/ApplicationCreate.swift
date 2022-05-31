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
import AppKit
#endif

public struct ApplicationRunOptions {
    public var initialScene: Scene?
    public var sceneName: String?
    
    public var windowConfiguration: WindowConfiguration
    
    public init(
        initialScene: Scene? = nil,
        sceneName: String? = nil,
        windowConfiguration: WindowConfiguration = WindowConfiguration()
    ) {
        self.initialScene = initialScene
        self.sceneName = sceneName
        self.windowConfiguration = windowConfiguration
    }
}

public extension ApplicationRunOptions {
    struct WindowConfiguration {
        public var windowClass: Window.Type?
        public var windowMode: Window.Mode = .windowed
        
        public init(windowClass: Window.Type? = nil, windowMode: Window.Mode = .windowed) {
            self.windowClass = windowClass
            self.windowMode = windowMode
        }
    }
}

// swiftlint:disable identifier_name

/// Create application instance
/// - Tag: ApplicationCreate
@discardableResult
public func ApplicationCreate(
    argc: Int32 = CommandLine.argc,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> = CommandLine.unsafeArgv,
    options: ApplicationRunOptions = ApplicationRunOptions()
) -> Int32 {
    do {
        var application: Application!
        
        #if os(macOS)
        application = try MacApplication(argc: argc, argv: argv)
        #endif
        
        #if os(iOS) || os(tvOS)
        application = try iOSApplication(argc: argc, argv: argv)
        #endif
        
        Application.shared = application
        
        var scene: Scene? = options.initialScene
        
        let windowClass = options.windowConfiguration.windowClass ?? Window.self
        let frame = Rect(origin: .zero, size: Size(width: 800, height: 600))
        
        var window: Window?
        
        if let scene = scene {
//            let size = NSScreen.main?.frame.size ?? .zero
//            let frame = Rect(origin: .zero, size: Size(width: Float(size.width), height: Float(size.height)))
            window = windowClass.init(scene: scene, frame: frame)
        } else {
            window = windowClass.init(frame: frame)
        }
        
        if window == nil {
            print("We don't have any window to present")
            return EXIT_FAILURE
        }
        
        window?.showWindow(makeFocused: true)
        
        try application.run(options: options)
        
        return EXIT_SUCCESS
    } catch {
        return EXIT_FAILURE
    }
}

// swiftlint:enable identifier_name
