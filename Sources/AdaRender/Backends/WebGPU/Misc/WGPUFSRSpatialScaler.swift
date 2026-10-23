#if WEBGPU_ENABLED && canImport(WebGPU)
    import Foundation
    import Synchronization
    #if WASM
        import JavaScriptKit
    #endif
    @unsafe @preconcurrency import WebGPU

    #if WASM
        private typealias FSRBinding = WebGPU.GPUBindGroupEntryEx
    #else
        private typealias FSRBinding = WebGPU.GPUBindGroupEntry
    #endif

    /// Device-owned FSR 1 resources. The lock protects vendor handles and cache mutation;
    /// webGPUDeviceLock serializes device calls with the rest of the backend.
    final class WGPUFSRSpatialScaler: @unchecked Sendable {
        private struct Key: Hashable {
            let inputWidth: Int
            let inputHeight: Int
            let outputWidth: Int
            let outputHeight: Int
        }

        private struct Picture {
            let texture: WebGPU.GPUTexture
            let view: WebGPU.GPUTextureView
            let constants: WebGPU.GPUBuffer
            let rcasBindings: WebGPU.GPUBindGroup
        }

        private struct Pipelines {
            let bindings: WebGPU.GPUBindGroupLayout
            let easu: WebGPU.GPURenderPipeline
            let rcasRGBA: WebGPU.GPURenderPipeline
            let rcasBGRA: WebGPU.GPURenderPipeline
        }

        private let lock = NSLock()
        private var pipelines: Pipelines?
        private var pictures: [Key: Picture] = [:]
        private static let maximumCachedPictures = 8

        func encode(source: WGPUGPUTexture, destination: WGPUGPUTexture, command: WGPUCommandEncoder) -> Bool {
            let input = source.texture
            let output = destination.texture
            // FSR 1 runs on perceptual, tone-mapped color. HDR and sRGB views require
            // explicit color conversion and use the caller's fallback for now.
            guard source !== destination,
                input.width > 0, input.height > 0,
                input.width <= output.width, input.height <= output.height,
                input.width < output.width || input.height < output.height,
                input.depthOrArrayLayers == 1, output.depthOrArrayLayers == 1,
                Self.isCompatible(input, usage: .textureBinding),
                Self.isCompatible(output, usage: .renderAttachment),
                input.format == .RGBA8Unorm || input.format == .BGRA8Unorm,
                output.format == .RGBA8Unorm || output.format == .BGRA8Unorm
            else {
                return false
            }

            return lock.withLock {
                webGPUDeviceLock.withLock { _ in
                    let device = command.device
                    let pipelines = self.pipelines ?? makePipelines(device: device)
                    self.pipelines = pipelines
                    let key = Key(
                        inputWidth: Int(input.width),
                        inputHeight: Int(input.height),
                        outputWidth: Int(output.width),
                        outputHeight: Int(output.height)
                    )
                    guard let picture = pictures[key] ?? makePicture(key, device: device, bindings: pipelines.bindings) else {
                        return false
                    }
                    if pictures[key] == nil {
                        if pictures.count >= Self.maximumCachedPictures, let stale = pictures.keys.first { pictures[stale] = nil }
                        pictures[key] = picture
                    }
                    // Do not cache the source or drawable: their lifetime belongs to the command buffer.
                    let easuBindings = bindGroup(device: device, layout: pipelines.bindings, entries: [
                        .init(binding: 0, textureView: source.textureView),
                        .init(binding: 1, buffer: picture.constants, size: 16),
                    ])
                    pass("FSR 1 EASU", into: picture.view, pipeline: pipelines.easu, bindings: easuBindings, command: command)
                    pass(
                        "FSR 1 RCAS",
                        into: destination.textureView,
                        pipeline: output.format == .RGBA8Unorm ? pipelines.rcasRGBA : pipelines.rcasBGRA,
                        bindings: picture.rcasBindings,
                        command: command
                    )
                    return true
                }
            }
        }

        private static func isCompatible(_ texture: WebGPU.GPUTexture, usage: WebGPU.GPUTextureUsage) -> Bool {
            #if WASM
                // Swan does not expose these read-only WebGPU properties on its WASM wrapper.
                let object = texture.jsObject
                guard object.sampleCount.number == 1, object.dimension.string == "2d",
                    let bits = object.usage.number, bits.isFinite, bits >= 0, bits <= Double(UInt32.max) else {
                    return false
                }
                return UInt32(bits) & usage.rawValue == usage.rawValue
            #else
                return texture.sampleCount == 1 && texture.dimension == ._2D && texture.usage.contains(usage)
            #endif
        }

        private func bindGroup(
            device: WebGPU.GPUDevice,
            layout: WebGPU.GPUBindGroupLayout,
            entries: [FSRBinding]
        ) -> WebGPU.GPUBindGroup {
            #if WASM
                device.createBindGroup(layout: layout, entries: entries)
            #else
                device.createBindGroup(descriptor: .init(layout: layout, entries: entries))
            #endif
        }

        private func makePipelines(device: WebGPU.GPUDevice) -> Pipelines {
            let bindings = device.createBindGroupLayout(descriptor: .init(entries: [
                .init(binding: 0, visibility: .fragment, texture: .init(sampleType: .unfilterableFloat)),
                .init(binding: 1, visibility: .fragment, buffer: .init(type: .uniform)),
            ]))
            let layout = device.createPipelineLayout(descriptor: .init(bindGroupLayouts: [bindings]))
            func pipeline(_ code: String, _ name: String, _ format: WebGPU.GPUTextureFormat) -> WebGPU.GPURenderPipeline {
                #if WASM
                    let shader = device.createShaderModule(descriptor: .init(label: name, code: code))
                #else
                    let shader = device.createShaderModule(descriptor: .init(label: name, nextInChain: WebGPU.GPUShaderSourceWGSL(code: code)))
                #endif
                return device.createRenderPipeline(descriptor: .init(
                    label: name,
                    layout: layout,
                    vertex: .init(module: shader, entryPoint: "vertex", buffers: []),
                    primitive: .init(topology: .triangleList, frontFace: .CCW, cullMode: .none),
                    multisample: .init(count: 1, mask: 1, alphaToCoverageEnabled: false),
                    fragment: .init(module: shader, entryPoint: "fragment", targets: [.init(format: format)])
                ))
            }
            return Pipelines(
                bindings: bindings,
                easu: pipeline(WGPUFSRShaders.easu, "FSR 1 EASU", .RGBA16Float),
                rcasRGBA: pipeline(WGPUFSRShaders.rcas, "FSR 1 RCAS RGBA", .RGBA8Unorm),
                rcasBGRA: pipeline(WGPUFSRShaders.rcas, "FSR 1 RCAS BGRA", .BGRA8Unorm)
            )
        }

        private func makePicture(_ key: Key, device: WebGPU.GPUDevice, bindings: WebGPU.GPUBindGroupLayout) -> Picture? {
            let texture = device.createTexture(descriptor: .init(
                label: "FSR 1 EASU output",
                usage: [.renderAttachment, .textureBinding],
                size: .init(width: UInt32(key.outputWidth), height: UInt32(key.outputHeight), depthOrArrayLayers: 1),
                format: .RGBA16Float
            ))
            let view = texture.createView()
            let created: WebGPU.GPUBuffer? = device.createBuffer(descriptor: .init(label: "FSR 1 scale", usage: [.uniform, .copyDst], size: 16))
            guard let constants = created else {
                return nil
            }
            // Immutable per-size constants avoid queue.writeBuffer races across unsubmitted views.
            var scale = SIMD4<Float>(Float(key.inputWidth) / Float(key.outputWidth), Float(key.inputHeight) / Float(key.outputHeight), 0, 0)
            unsafe withUnsafeBytes(of: &scale) { bytes in
                unsafe device.queue.writeBuffer(buffer: constants, bufferOffset: 0, data: bytes)
            }
            let rcasBindings = bindGroup(device: device, layout: bindings, entries: [
                .init(binding: 0, textureView: view), .init(binding: 1, buffer: constants, size: 16),
            ])
            return Picture(texture: texture, view: view, constants: constants, rcasBindings: rcasBindings)
        }

        private func pass(
            _ label: String,
            into destination: WebGPU.GPUTextureView,
            pipeline: WebGPU.GPURenderPipeline,
            bindings: WebGPU.GPUBindGroup,
            command: WGPUCommandEncoder
        ) {
            let pass = command.commandEncoder.beginRenderPass(descriptor: .init(label: label, colorAttachments: [
                .init(view: destination, loadOp: .clear, storeOp: .store, clearValue: .init(r: 0, g: 0, b: 0, a: 0)),
            ]))
            pass.setPipeline(pipeline: pipeline)
            pass.setBindGroup(groupIndex: 0, group: bindings, dynamicOffsets: [])
            pass.draw(vertexCount: 3, instanceCount: 1, firstVertex: 0, firstInstance: 0)
            pass.end()
        }
    }
#endif
