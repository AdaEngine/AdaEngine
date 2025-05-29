//
//  AppContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/30/24.
//

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
        guard let appScene = app.body as? InternalAppScene else {
            fatalError("Incorrect object of App Scene")
        }

//        let filePath = appScene._getFilePath()
//        try AssetsManager.initialize(filePath: filePath)
//        RuntimeTypeLoader.loadTypes()

        LoggingSystem.bootstrap {
            StreamLogHandler.standardError(label: $0)
        }

        var configuration = _AppSceneConfiguration()
        appScene._buildConfiguration(&configuration)
        let appBuilder = configuration.appBuilder
        try appBuilder.build()
        appBuilder.runner?(appBuilder)
//
//        Task { @MainActor in
//            let window = try await appScene._makeWindow(with: configuration)
//            await self.application.renderWorld.addPlugin(DefaultRenderPlugin())
//
//            window.showWindow(makeFocused: true)
//        }
    }
}
