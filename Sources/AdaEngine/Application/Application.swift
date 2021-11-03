//
//  Application.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

import Foundation.NSURL

public class Application {
    
    let gameLoop: GameLoop
    
    // MARK: - Public
    
    /// Contains application instance if application created from `ApplicationCreate`
    public internal(set) static var shared: Application!
    
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
    
    // MARK: - Internal
    
    required init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        self.gameLoop = GameLoop.current
    }
    
    func run() throws {
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
}
