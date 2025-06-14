//
//  Bundle+AdaEngine.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

import Foundation

public extension Foundation.Bundle {
    static var engineBundle: Foundation.Bundle {
#if SWIFT_PACKAGE && !BAZEL_BUILD
        return Foundation.Bundle.module
#else
        return Foundation.Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE || BAZEL_BUILD
class BundleToken {}
#endif
