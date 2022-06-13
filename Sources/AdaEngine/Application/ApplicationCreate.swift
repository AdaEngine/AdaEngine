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

/// A type that represents the structure and behavior of an app.
public protocol App {
    /// Creates an instance of the app using the body that you define for its content.
    init()
    
    associatedtype Content: AppScene
    var scene: Content { get }
}

public extension App {
    
    init() {
        self.init()
    }
    
    // Initializes and runs the app.
    static func main() async throws {
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
        let window = appScene._makeWindow(with: configuration)
        
        window.showWindow(makeFocused: true)
        
        try application.run()
    }
}

enum AppError: LocalizedError {
    case configurationFailure
}

public protocol AppScene {
    associatedtype Body: AppScene
    var scene: Body { get }
    
    var _configuration: _AppSceneConfiguration { get set }
    func _makeWindow(with configuration: _AppSceneConfiguration) -> Window
}

public extension AppScene {
    func minimumSize(_ size: Size) -> some AppScene {
        var newValue = self
        newValue._configuration.minimumSize = size
        return newValue
    }
    
    func windowMode(_ mode: Window.Mode) -> some AppScene {
        var newValue = self
        newValue._configuration.windowMode = mode
        return newValue
    }
    
    func singleWindow(_ isSingleWindow: Bool) -> some AppScene {
        var newValue = self
        newValue._configuration.isSingleWindow = isSingleWindow
        return newValue
    }
}

public struct _AppSceneConfiguration {
    var frame: Rect = .zero
    var minimumSize: Size = Size(width: 800, height: 600)
    var windowMode: Window.Mode = .fullscreen
    var isSingleWindow: Bool = false
}

extension Never: AppScene {
    public var _configuration: _AppSceneConfiguration {
        get {
            fatalError()
        }
        // swiftlint:disable:next unused_setter_value
        set {
            fatalError()
        }
    }
    
    public var scene: Never {
        fatalError()
    }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) -> Window {
        fatalError()
    }
}


/// GUI App Scene relative to work with GUI Applications.
/// That match for application without needed to implement game logic.
public struct GUIAppScene: AppScene {
    public var scene: Never { fatalError() }
    
    public var _configuration = _AppSceneConfiguration()
    let window: () -> Window
    
    /// - Parameters window: Window for presenting on screen
    public init(window: @escaping () -> Window) {
        self.window = window
    }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) -> Window {
        let window = window()
        window.frame = Rect(origin: .zero, size: configuration.minimumSize)
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        return window
    }
}

public struct GameScene: AppScene {
    
    public var scene: Never { fatalError() }
    
    public var _configuration = _AppSceneConfiguration()
    let gameScene: () -> Scene
    
    public init(scene: @escaping () -> Scene) {
        self.gameScene = scene
    }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) -> Window {
        let scene = self.gameScene()
        let window = Window(scene: scene, frame: Rect(origin: .zero, size: configuration.minimumSize))
        window.setWindowMode(configuration.windowMode)
        window.minSize = configuration.minimumSize
        return window
    }
}
