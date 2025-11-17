//
//  AppContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/30/24.
//

import AdaECS
import AdaUtils
import Logging

/// The context of the app.
@MainActor
@_spi(Internal)
public struct AppContext<T: App>: ~Copyable {
    /// The app.
    private let app: T

    /// Initialize a new app context.
    /// - Throws: An error if the app cannot be initialized.
    init() throws {
        self.app = T.init()
    }
    
    /// Initialize a new app context.
    /// - Parameter app: The app to initialize the context with.
    @_spi(Internal)
    public init(_ app: T) {
        self.app = app
    }

    /// Run the app.
    /// - Throws: An error if the app cannot be run.
    @_spi(Internal)
    public func run() throws {
        LoggingSystem.bootstrap {
            StreamLogHandler.standardError(label: $0)
        }
        let appWorlds = AppWorlds(main: World(name: "MainWorld"))
        appWorlds
            .insertResource(WindowSettings())
            .addPlugin(MainSchedulerPlugin())

        let inputs = _SceneInputs(appWorlds: appWorlds)
        let node = _AppSceneNode(value: app.body)
        let _ = T.Content._makeView(node, inputs: inputs)
        
        try appWorlds.build()
        appWorlds.runner?(appWorlds)
    }
}
