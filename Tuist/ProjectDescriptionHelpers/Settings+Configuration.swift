//
//  Settings+Configuration.swift
//  ProjectDescriptionHelpers
//
//  Created by v.prusakov on 2/25/23.
//

import ProjectDescription

public extension Settings {
    
    static var editor: Settings {
        Settings.settings(
            configurations: Configuration.defaults(with: [.app, .settings])
        )
    }
    
    static var common: Settings {
        Settings.settings(
            base: [
                "PRODUCT_BUNDLE_IDENTIFIER": "org.adaengine"
            ],
            configurations: Configuration.defaults(with: [.settings]))
    }
}

extension Configuration {
    
    static func defaults(with options: Options) -> [Configuration] {
        [
            .debug(configuration: .debug, with: options),
            .release(configuration: .release, with: options),
        ]
    }
    
    static func debug(
        configuration: AppConfiguration,
        with options: Options
    ) -> Configuration {
        Configuration.debug(
            name: .configuration(configuration.rawValue),
            settings: options.contains(.settings) ? configuration.settings(isAppSettings: options.contains(.app)) : [:],
            xcconfig: nil
        )
    }
    
    static func release(
        configuration: AppConfiguration,
        with options: Options
    ) -> Configuration {
        Configuration.release(
            name: .configuration(configuration.rawValue),
            settings: options.contains(.settings) ? configuration.settings(isAppSettings: options.contains(.app)) : [:],
            xcconfig: nil
        )
    }
    
    struct Options: OptionSet {
        var rawValue: UInt8
        
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        static let settings = Options(rawValue: 1 << 0)
        static let app = Options(rawValue: 1 << 1)
        
        static let none: Options = []
    }
}

