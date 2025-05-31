
//
//  AppPlatformPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaApp
import AdaECS

public struct AppPlatformPlugin: Plugin {

    public init() {}

    @MainActor
    public func setup(in app: AppWorlds) {
        let argc = CommandLine.argc
        let argv = CommandLine.unsafeArgv

        do {
            let application: Application
#if os(macOS)
            application = try MacApplication(argc: argc, argv: argv)
#endif

#if os(iOS) || os(tvOS)
            application = try iOSApplication(argc: argc, argv: argv)
#endif

#if os(Android)
            application = try AndroidApplication(argc: argc, argv: argv)
#endif

#if os(Linux)
            application = try LinuxApplication(argc: argc, argv: argv)
#endif
            
            Application.shared = application
            app.mainWorld.insertResource(application)

            app.setRunner { worlds in
                do {
                    try MainActor.assumeIsolated {
                        try application.run(worlds)
                    }
                } catch {
                    print(error)
                }
            }

        } catch {
            fatalError("Can't initialise application: \(error)")
        }
    }
}
