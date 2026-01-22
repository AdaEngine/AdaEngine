//
//  MetalBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import AdaUtils
import Foundation
import WebGPU
import CWebGPU

@_spi(Internal)
public class WGPUBuffer: Buffer, @unchecked Sendable {
    let buffer: WebGPU.Buffer
    let device: WebGPU.Device
    
    public var label: String? {
        didSet {
            self.buffer.setLabel(label ?? "")
        }
    }
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device) {
        self.buffer = buffer
        self.device = device
    }
    
    public var length: Int { return Int(buffer.size) }

    private var mappedBuffer: WebGPU.Buffer?

    public func contents() -> UnsafeMutableRawPointer {
        let mappedBuffer = self.device.createBuffer(
            descriptor: BufferDescriptor(
                usage: [.mapWrite, .copySrc], 
                size: UInt64(self.length),
                mappedAtCreation: true
            )
        ).unwrap(message: "Failed to create mapped buffer")
        self.mappedBuffer = mappedBuffer
        return unsafe mappedBuffer.getMappedRange()
    }

    public func unmap() {
        guard let mappedBuffer = self.mappedBuffer else {
            return
        }

        unsafe device.queue.writeBuffer(
            buffer,
            bufferOffset: 0,
            data: UnsafeRawBufferPointer(start: self.contents(), count: self.length)
        )

        mappedBuffer.unmap()
        self.mappedBuffer = nil
    }
    
    public func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        unsafe device.queue.writeBuffer(
            self.buffer, 
            bufferOffset: UInt64(offset), 
            data: UnsafeRawBufferPointer(start: bytes, count: byteCount)
        )
    }

    enum MapError: Error {
        case failedToGetMappedRange
        case failedToMap(String)
    }
}

extension BufferMapMode {
    var toWebGPU: WebGPU.MapMode {
        switch self {
        case .read:
            return .read
        case .write:
            return .write
        default:
            return .none
        }
    }
}

#endif
