//
//  AABB.swift
//  Math
//
//  Created by v.prusakov on 1/7/23.
//

import Foundation

public struct AABB: Equatable, Hashable, Codable {
    public var min: Vector3
    public var max: Vector3
    
    public init(min: Vector3, max: Vector3) {
        self.min = min
        self.max = max
    }
    
    public init() {
        self.min = .zero
        self.max = .zero
    }
}
