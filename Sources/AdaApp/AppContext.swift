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

    private var app: T
//    private var application: Application!

    init() throws {
        self.app = T.init()
    }
    
    @_spi(Internal)
    public init(_ app: T) {
        self.app = app
    }

    @_spi(Internal)
    public func run() throws {
//        let filePath = appScene._getFilePath()
//        try AssetsManager.initialize(filePath: filePath)

        LoggingSystem.bootstrap {
            StreamLogHandler.standardError(label: $0)
        }

        let appWorlds = AppWorlds(mainWorld: World(name: "MainWorld"), subWorlds: [:])
        appWorlds.insertResource(WindowSettings())
        let inputs = _SceneInputs(appWorlds: appWorlds)
        let node = _AppSceneNode(value: app.body)
        let _ = T.Content._makeView(node, inputs: inputs)
        try appWorlds.build()
        appWorlds.runner?(appWorlds)
        
//        Task { @MainActor in
//            let window = try await appScene._makeWindow(with: configuration)
//            await self.application.renderWorld.addPlugin(DefaultRenderPlugin())
//
//            window.showWindow(makeFocused: true)
//        }
    }
}
