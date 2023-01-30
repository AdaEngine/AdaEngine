//
//  UniformBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

public protocol UniformBuffer: Buffer {
    var binding: Int { get }
}
