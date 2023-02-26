//
//  Constants.swift
//  ProjectDescriptionHelpers
//
//  Created by v.prusakov on 2/25/23.
//

extension String {
    
    /// If you pass the key `PRODUCT_BUNDLE_IDENTIFIER` in settings, this method can set additional name for you.
    /// - Parameter name: Additional name for $(PRODUCT_BUNDLE_IDENTIFIER).
    /// - Returns: $(PRODUCT_BUNDLE_IDENTIFIER) + name.
    public static func bundleIdentifier(name: String? = nil) -> String {
        return "$(PRODUCT_BUNDLE_IDENTIFIER)" + (name.flatMap { ".\($0)" } ?? "")
    }
    
}
