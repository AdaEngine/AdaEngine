//
//  ApplicationCreate.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

/// A type that represents the structure and behavior of an app.
@MainActor @preconcurrency
public protocol App: Sendable {

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
    static func main() async throws {
        let appContext = try AppContext<Self>()
        try await appContext.setup()
        try appContext.runApplication()
    }
}
