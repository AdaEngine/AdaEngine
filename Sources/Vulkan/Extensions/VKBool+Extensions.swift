//
//  File.swift
//  
//
//  Created by v.prusakov on 8/13/21.
//

import CVulkan

extension VkBool32: @retroactive ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = value ? VK_TRUE : VK_FALSE
    }
    
    public var boolValue: Bool { Bool(self) }
}

public extension Bool {
    init(_ vkBool: VkBool32) {
        self = (vkBool == VK_TRUE) ? true : false
    }
}
