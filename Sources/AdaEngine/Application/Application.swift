//
//  Application.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

import Foundation.NSURL

/// Main class represented application instance.
/// Application cannot be created manualy use [ApplicationCreate](x-source-tag://ApplicationCreate) function instead.
/// To get access to Application instance, use static property `shared`
open class Application {
    
    // MARK: - Public
    
    /// Contains application instance if application created from [ApplicationCreate](x-source-tag://ApplicationCreate) function.
    public internal(set) static var shared: Application!
    
    private(set) var gameLoop: GameLoop = GameLoop.current
    
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
    
    public var windowManager: WindowManager = WindowManager()
    
    // MARK: - Internal
    
    public init(
        argc: Int32,
        argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws { }
    
    /// Call this method to start main loop.
    func run(options: ApplicationRunOptions) throws {
        assertionFailure("Not implemented")
    }
    
    // MARK: - Public methods
    
    open func terminate() {
        exit(EXIT_SUCCESS)
    }
    
    @discardableResult
    open func openURL(_ url: URL) -> Bool {
        assertionFailure("Not implemented")
        return false
    }
    
    /// Call this method to show specific alert.
    open func showAlert(_ alert: Alert) {
        assertionFailure("Not implemented")
    }
}
