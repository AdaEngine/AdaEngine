//
//  IndexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

// TODO: (Vlad) Add documentations

public enum IndexBufferFormat: UInt8 {
    case uInt32
    case uInt16
}

public protocol IndexBuffer: Buffer {
    var indexFormat: IndexBufferFormat { get }
    var offset: Int { get }
}
