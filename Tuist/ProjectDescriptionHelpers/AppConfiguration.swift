//
//  AppConfiguration.swift
//  ProjectDescriptionHelpers
//
//  Created by v.prusakov on 2/25/23.
//

import ProjectDescription

public enum AppConfiguration: String {
    case debug = "Debug"
    case release = "Release"
}

public extension AppConfiguration {
    var optimizationLevel: String {
        switch self {
        case .debug:
            return SwiftOptimizationLevel.oNone.rawValue
        case .release:
            return SwiftOptimizationLevel.o.rawValue
        }
    }
    
    var compilationMode: String {
        switch self {
        case .debug:
            return SwiftCompilationMode.singlefile.rawValue
        case .release:
            return SwiftCompilationMode.wholemodule.rawValue
        }
    }
    
    func settings(isAppSettings: Bool) -> SettingsDictionary {
        return AppSettings.make(for: self, isAppSettings: isAppSettings)
    }
}
