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
public protocol App {

    /// Creates an instance of the app using the body that you define for its content.
    @MainActor(unsafe)
    init()

    associatedtype Content: AppScene
    
    /// Main scene in your app.
    @MainActor(unsafe)
    var scene: Content { get }
}

public extension App {
    
    init() {
        self.init()
    }
    
    // Initializes and runs the app.
    static func main() throws {
        let appContext = try AppContext<Self>()
        try appContext.setup()

        try appContext.runApplication()
    }
}