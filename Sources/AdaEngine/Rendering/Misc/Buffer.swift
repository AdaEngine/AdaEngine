//
//  Buffer.swift
//  
//
//  Created by v.prusakov on 11/4/21.
//

// TODO: (Vlad) Add documentation.

public protocol Buffer: AnyObject {
    
    func contents() -> UnsafeMutableRawPointer
    
    var label: String? { get set }
    
    var length: Int { get }
    
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int)
}

public extension Buffer {
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int) {
        self.setData(bytes, byteCount: byteCount, offset: 0)
    }
    
    // TODO: (Vlad) Looks how it works with arrays
    func setData<T>(_ value: T) {
        let size = MemoryLayout<T>.size
        
        var value = value
        self.setData(&value, byteCount: size)
    }
}

public struct ResourceOptions: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let storagePrivate = ResourceOptions(rawValue: 1 << 0)
    
    public static let storageShared = ResourceOptions(rawValue: 1 << 1)
}
