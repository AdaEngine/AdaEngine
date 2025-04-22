//
//  VulkanUtils.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/24.
//

import Foundation

public enum VulkanUtils {

    /// Helper to hold and release all pointers.
    public class TemporaryBufferHolder: CustomStringConvertible {
        private var buffers: [UnsafeRawPointer] = []

        let label: String

        public init(label: String) {
            self.label = label
        }

        deinit {
            for ptr in buffers {
                ptr.deallocate()
            }
        }
        
        public var description: String {
            return "Temporary Buffer Holder: \(label). Contains \(buffers.count) pointers"
        }
        
        // MARK: Public

        public func unsafePointerCopy<T>(from object: T) -> UnsafePointer<T> {
            let buffer: UnsafeMutablePointer<T> = .allocate(capacity: 1)
            withUnsafePointer(to: object) {
                buffer.initialize(from: $0, count: 1)
            }
            self.buffers.append(buffer)
            return UnsafePointer<T>(buffer)
        }

        public func unsafePointerCopy(string str: String) -> UnsafePointer<CChar>? {
            let buffer = str.withCString { ptr in
                let count = strlen(ptr) + 1
                let buffer: UnsafeMutablePointer<CChar> = .allocate(capacity: count)
                buffer.initialize(from: ptr, count: count)
                return UnsafePointer(buffer)
            }
            self.buffers.append(buffer)
            return buffer
        }

        public func unsafePointerCopy<C>(collection source: C) -> UnsafePointer<C.Element>? where C: Collection {
            if source.isEmpty { return nil }

            let buffer: UnsafeMutableBufferPointer<C.Element> = .allocate(capacity: source.count)
            _ = buffer.initialize(from: source)
            let ptr = UnsafePointer<C.Element>(buffer.baseAddress!)
            self.buffers.append(ptr)
            return ptr
        }
    }

}
