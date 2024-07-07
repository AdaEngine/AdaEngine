//
//  Application.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

/// The main class represents application instance.
/// The application cannot be created manualy, instead use an ``App`` protocol.
/// To get access to the application instance, use static property `shared`
open class Application {

    // MARK: - Public
    
    /// Contains application instance if application created from ``App``.
    public internal(set) static var shared: Application!

    @MainActor let gameLoop: GameLoop = GameLoop.current

    /// Current runtime platform.
    public var platform: RuntimePlatform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #elseif os(Android)
        return .android
        #endif
    }
    
    @MainActor(unsafe) public var windowManager: WindowManager = WindowManager()

    /// Contains world which can render on screen.
    @RenderGraphActor public let renderWorld = RenderWorld()
    
    // MARK: - Internal
    
    public nonisolated init(
        argc: Int32,
        argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws {
        Self.shared = self
    }

    /// Call this method to start main loop.
    func run() throws {
        assertionFailure("Not implemented")
    }
    
    // MARK: - Public methods
    
    /// Call this method to terminate app execution with 0 status code.
    @MainActor 
    open func terminate() {
        exit(EXIT_SUCCESS)
    }
    
    /// Method to open url.
    @MainActor
    @discardableResult
    open func openURL(_ url: URL) -> Bool {
        assertionFailure("Not implemented")
        return false
    }
    
    /// Call this method to show specific alert.
    @MainActor
    open func showAlert(_ alert: Alert) {
        assertionFailure("Not implemented")
    }
}

public extension Application {
    
    /// The collection of available Application States.
    enum State {
        case active
        case inactive
        case background
    }
}
