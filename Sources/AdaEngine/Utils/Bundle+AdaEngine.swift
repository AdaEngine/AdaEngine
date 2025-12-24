//
//  Bundle+AdaEngine.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

import Foundation

public extension Bundle {
    static var engineBundle: Bundle {
#if SWIFT_PACKAGE && !BAZEL_BUILD
        return Bundle.module
#else
        return Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE || BAZEL_BUILD
class BundleToken {}
#endif
