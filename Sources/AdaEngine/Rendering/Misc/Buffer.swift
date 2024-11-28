//
//  Buffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/4/21.
//

/// This protocol describe buffer created for GPU usage.
public protocol Buffer: AnyObject {
    
    /// Gets the system address of the buffer’s storage allocation.
    ///
    /// - Returns: A pointer to the shared copy of the buffer data, or NULL for buffers allocated with a private resource storage mode
    func contents() -> UnsafeMutableRawPointer
    
    /// A string that identifies the resource.
    var label: String? { get set }
    
    /// The logical size of the buffer, in bytes.
    var length: Int { get }
    
    /// Set data to the buffer's storage.
    /// - Parameter bytes: A pointer to the data which will be copied.
    /// - Parameter byteCount: Count of bytes which will be copied.
    /// - Parameter offset: Offset position where want to place copied data.
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int)
}

public extension Buffer {
    
    /// Set data to the buffer's storage.
    /// - Parameter bytes: A pointer to the data which will be copied.
    /// - Parameter byteCount: Count of bytes which will be copied.
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int) {
        self.setData(bytes, byteCount: byteCount, offset: 0)
    }
    
    /// Set data to the buffer's storage.
    /// - Parameter value: A value which will be copied.
    func setData<T>(_ value: T) {
        let size = MemoryLayout<T>.stride
        
        withUnsafePointer(to: value) { ptr in
            self.setData(UnsafeMutableRawPointer(mutating: ptr), byteCount: size)
        }
    }
}

/// Options for the memory location and access permissions for a resource.
public struct ResourceOptions: OptionSet, Sendable {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    /// The resource can be accessed only by the GPU.
    public static let storagePrivate = ResourceOptions(rawValue: 1 << 0)
    
    /// The resource is stored in system memory and is accessible to both the CPU and the GPU.
    public static let storageShared = ResourceOptions(rawValue: 1 << 1)
    
    /// The CPU and GPU may maintain separate copies of the resource, which you need to explicitly synchronize.
    @available(macOS 11, *)
    public static let storageManaged = ResourceOptions(rawValue: 1 << 2)
}
