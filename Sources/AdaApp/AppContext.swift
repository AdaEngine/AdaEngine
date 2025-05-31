//
//  AppContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/30/24.
//

import AdaECS
import AdaUtils
import Logging

@MainActor
@_spi(Internal)
public final class AppContext<T: App> {
    private let app: T

    init() throws {
        self.app = T.init()
    }
    
    @_spi(Internal)
    public init(_ app: T) {
        self.app = app
    }

    @_spi(Internal)
    public func run() throws {
        LoggingSystem.bootstrap {
            StreamLogHandler.standardError(label: $0)
        }
        let appWorlds = AppWorlds(mainWorld: World(name: "MainWorld"))
        appWorlds.insertResource(WindowSettings())
        let inputs = _SceneInputs(appWorlds: appWorlds)
        let node = _AppSceneNode(value: app.body)
        let _ = T.Content._makeView(node, inputs: inputs)
        try appWorlds.build()
        appWorlds.runner?(appWorlds)
    }
}
