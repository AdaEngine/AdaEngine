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

func convertTupleToArray<T, Element>(tuple: T, start: UnsafePointer<Element>) -> [Element] {
    return [Element](
        UnsafeBufferPointer(
            start: start,
            count: MemoryLayout.size(ofValue: tuple)/MemoryLayout<Element>.size
        )
    )
}

/// Helper method to check Vulkan results
/// - Parameter result: VkResult value
/// - Parameter message: Localized error message if VkResult is not a VK_SUCCESS
/// - Throws: `VKError` with result code and user message
public func vkCheck(_ result: VkResult, _ message: String = "") throws {
    guard result == VK_SUCCESS else {
        throw VKError(code: result, message: message)
    }
}

//#if canImport(Foundation)
//import Foundation
//
//extension String {
//    
//    // TODO: Replace to closure like sintax"
//    func asCString() -> UnsafePointer<CChar>? {
//        let cString = (self as NSString).utf8String
//        return cString
//    }
//
//
//}
//#endif

extension String {
    func toPointer() -> UnsafePointer<CChar>? {
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }

        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: data.count)
        let pointer = data.withUnsafeBytes { pointer in
            return pointer.baseAddress?.bindMemory(to: CChar.self, capacity: data.count)
        }

        guard let pointer else {
            return nil
        }

        buffer.initialize(from: pointer, count: data.count)

        return UnsafePointer<CChar>(buffer)
    }
}
