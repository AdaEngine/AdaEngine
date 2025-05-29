//
//  Application.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

import AdaECS
@_spi(Internal) import AdaRender
import Foundation
import AdaUI

/// The main class represents application instance.
/// The application cannot be created manualy, instead use an ``App`` protocol.
/// To get access to the application instance, use static property `shared`
@MainActor
open class Application: Resource {
    
    /// Contains application instance if application created from ``App``.
    @MainActor public internal(set) static var shared: Application!

    let mainLoop: MainLoop = MainLoop.current

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
        #elseif os(visionOS)
        return .visionOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #elseif os(Android)
        return .android
        #endif
    }
    
    @_spi(Internal)
    @MainActor @preconcurrency
    public var windowManager: UIWindowManager = UIWindowManager()

    /// Contains world which can render on screen.
    public let renderWorld = RenderWorld()

    // MARK: - Internal
    
    public init(
        argc: Int32,
        argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws { }

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

public extension Application {
    @_spi(Internal)
    static func setApplication(_ app: Application) {
        self.shared = app
    }
}
