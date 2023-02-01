//
//  Project+AdaEngine.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription

public struct CompilerFlags {
    
    let value: String
    
    public static func define(_ name: String, to value: String = "1") -> CompilerFlags {
        var flagValue = "-D\(name)"
        
        if value != "1" {
            flagValue += "=\(value)"
        }
        
        return CompilerFlags(value: flagValue)
    }
}

public extension Settings {
    static var adaEngine: Settings {
        Settings.settings(base: [
            "PRODUCT_BUNDLE_IDENTIFIER": "org.adaengine",
        ])
    }
    
    static func targetSettings(
        swiftFlags: [CompilerFlags]? = nil,
        cFlags: [CompilerFlags]? = nil,
        cxxFlags: [CompilerFlags]? = nil
    ) -> Settings {
        
        var baseSettings: [String: SettingValue] = [
            "PRODUCT_BUNDLE_IDENTIFIER": "org.adaengine"
        ]
        
        if let flags = swiftFlags?.map({ $0.value }).joined(separator: " ") {
            baseSettings["OTHER_SWIFT_FLAGS"] = SettingValue(stringLiteral: flags)
        }
        
        if let flags = cxxFlags?.map({ $0.value }).joined(separator: " ") {
            baseSettings["OTHER_CPLUSPLUSFLAGS"] = SettingValue(stringLiteral: flags)
        }
        
        if let flags = cFlags?.map({ $0.value }).joined(separator: " ") {
            baseSettings["OTHER_CFLAGS"] = SettingValue(stringLiteral: flags)
        }
        
        return Settings.settings(base: baseSettings)
    }
}

private extension Platform {
    var flag: String {
        switch self {
        case .macOS: return "MACOS"
        case .iOS: return "IOS"
        case .tvOS: return "TVOS"
        case .watchOS: return "WATCHOS"
        default: return ""
        }
    }
}
