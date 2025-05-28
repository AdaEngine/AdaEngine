//
//  Exported.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

// File contains all exported frameworks, to avoid import this libs in client side.
// Like example, user can use Math library if he/she use imported only `AdaEngine`.
// Can be problem if swift deprecate this @_exported hack.

@_exported import Foundation
@_exported import Math
@_exported import AdaECS
@_exported import AdaUtils
@_exported import AdaAssets

public typealias TimeInterval = AdaUtils.TimeInterval
