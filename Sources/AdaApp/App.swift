//
//  ApplicationCreate.swift
//  AdaEngine
//
//  Created by v.prusakov on 10/9/21.
//

/// A type that represents the structure and behavior of an app.
@MainActor @preconcurrency
public protocol App: Sendable {

    /// The content of the app.
    associatedtype Content: AppScene

    /// Creates an instance of the app using the body that you define for its content.
    init()
    
    /// Main scene in your app.
    var body: Content { get }
}

public extension App {
    
    init() {
        self.init()
    }
    
    // Initializes and runs the app.
    static func main() async throws {
        let appContext = try AppContext<Self>()
        try appContext.run()
    }
}
