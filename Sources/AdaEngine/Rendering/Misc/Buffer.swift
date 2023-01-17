//
//  Buffer.swift
//  
//
//  Created by v.prusakov on 11/4/21.
//

// TODO: (Vlad) Add documentation.

public protocol Buffer: AnyObject {
    
    func contents() -> UnsafeMutableRawPointer
    
    var length: Int { get }
    
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int)
}

public extension Buffer {
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int) {
        self.setData(bytes, byteCount: byteCount, offset: 0)
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
