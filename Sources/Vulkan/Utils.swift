//
//  Utils.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif
import CVulkan

func convertTupleToUnsafePointer<T, U>(tuple: T, type: U.Type) -> UnsafePointer<U> {
    return withUnsafePointer(to: tuple) { pointer in
        pointer.withMemoryRebound(to: type, capacity: 1) { $0 }
    }
}

/// Helper method to check Vulkan results
/// - Parameter result: VkResult value
/// - Parameter message: Localized error message if VkResult is not a VK_SUCCESS
/// - Throws: `VKError` with result code and user message
func vkCheck(_ result: VkResult, _ message: String = "") throws {
    guard result == VK_SUCCESS else {
        throw VKError(code: result, message: message)
    }
}

#if canImport(Foundation)
import Foundation

extension String {
    
    // TODO: Replace to closure like sintax"
    func asCString() -> UnsafePointer<CChar>? {
        let cString = (self as NSString).utf8String
        return cString
    }
}
#endif
