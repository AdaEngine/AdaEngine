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
    private var application: Application!

    init() throws {
        self.app = T.init()
        
        let argc = CommandLine.argc
        let argv = CommandLine.unsafeArgv

#if os(macOS)
        self.application = try MacApplication(argc: argc, argv: argv)
#endif

#if os(iOS) || os(tvOS)
        self.application = try iOSApplication(argc: argc, argv: argv)
#endif

#if os(Android)
        self.application = try AndroidApplication(argc: argc, argv: argv)
#endif

#if os(Linux)
        self.application = try LinuxApplication(argc: argc, argv: argv)
#endif

        Application.shared = self.application
    }
    
    @_spi(Internal)
    public init(_ app: T) {
        self.app = app
        self.application = Application.shared
    }

    @_spi(Internal)
    public func setup() async throws {
        try ResourceManager.initialize()
        try AudioServer.initialize()
        RuntimeTypeLoader.loadTypes()

        LoggingSystem.bootstrap {
            StreamLogHandler.standardError(label: $0)
        }

        guard let appScene = app.scene as? InternalAppScene else {
            fatalError("Incorrect object of App Scene")
        }

        var configuration = _AppSceneConfiguration()
        appScene._buildConfiguration(&configuration)
        Task { @MainActor in
            let window = try await appScene._makeWindow(with: configuration)
            if configuration.useDefaultRenderPlugins {
                await self.application.renderWorld.addPlugin(DefaultRenderPlugin())
            }

            for plugin in configuration.renderPlugins {
                await self.application.renderWorld.addPlugin(plugin)
            }

            window.showWindow(makeFocused: true)
        }
    }
    
    @_spi(Internal)
    public func runApplication() throws {
        try AudioServer.shared.start()
        try self.application.run()
        try AudioServer.shared.stop()
    }
}
