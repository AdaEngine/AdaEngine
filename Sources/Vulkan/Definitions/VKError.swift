//
//  VKError.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan
import Foundation

public struct VKError: LocalizedError {

    public let code: VkResult
    public let message: String

    public var errorDescription: String? {
        return "Vulkan Error \(code.rawValue): \(self.message)"
    }
}
