//
//  VKError.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CVulkan

public struct VKError: Error {
    
    public let code: VkResult
    public let message: String
    
}

#if canImport(Foundation)

import Foundation

extension VKError: CustomNSError {
    public var errorDescription: String? {
        return self.message
    }
    
    public static var errorDomain: String = "ada.engine.vulkan.error"
    
    public var errorCode: Int {
        return Int(self.code.rawValue)
    }
}

#endif
