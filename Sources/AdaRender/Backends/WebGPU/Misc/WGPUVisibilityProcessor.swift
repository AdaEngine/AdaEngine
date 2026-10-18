#if WEBGPU_ENABLED && canImport(WebGPU)
    import Foundation
    import Math
    import Synchronization
    @unsafe @preconcurrency import WebGPU

    #if WASM
        private typealias VisibilityBinding = WebGPU.GPUBindGroupEntryEx
    #else
        private typealias VisibilityBinding = WebGPU.GPUBindGroupEntry
    #endif

    /// One camera owns this state. The lock protects its frame ring and caches; GPU calls use the device lock.
    final class WGPUVisibilityProcessor: GPUVisibilityProcessor, @unchecked Sendable {
        private struct View {
            var projection: Transform3D
            var width: UInt32
            var height: UInt32
            var count: UInt32
            var words: UInt32
        }
        private struct Frame {
            let candidates: WebGPU.GPUBuffer
            let constants: WebGPU.GPUBuffer
            let instances: WGPUBuffer
            let arguments: WGPUBuffer
            var input: WGPUBuffer?
            var group: WebGPU.GPUBindGroup?
        }
        // Immutable vendor handles cross Mutex's sending return in this bundle. Their creation and
        // subsequent GPU use are serialized by webGPUDeviceLock; the bundle exposes no mutations.
        private struct Pipelines: @unchecked Sendable {
            let reductionLayout: WebGPU.GPUBindGroupLayout
            let compactionLayout: WebGPU.GPUBindGroupLayout
            let copy: WebGPU.GPUComputePipeline
            let reduce: WebGPU.GPUComputePipeline
            let compact: WebGPU.GPUComputePipeline
        }
        private let lock = NSLock()
        private let context: WGPUContext
        private let reductionLayout: WebGPU.GPUBindGroupLayout
        private let compactionLayout: WebGPU.GPUBindGroupLayout
        private let copy: WebGPU.GPUComputePipeline
        private let reduce: WebGPU.GPUComputePipeline
        private let compact: WebGPU.GPUComputePipeline
        private var frames: [Frame?]
        private var frame = 0
        private var size = SizeInt.zero
        private var pyramid: WebGPU.GPUTexture?
        private var pyramidView: WebGPU.GPUTextureView?
        private var levels: [WebGPU.GPUTextureView] = []
        private var reductions: [WebGPU.GPUBindGroup] = []
        private var source: WGPUGPUTexture?
        private var copyGroup: WebGPU.GPUBindGroup?

        init(context: WGPUContext) {
            self.context = context
            let device = context.device
            let pipelines = webGPUDeviceLock.withLock { _ in
                let reductionLayout = device.createBindGroupLayout(descriptor: .init(entries: [
                    .init(binding: 0, visibility: .compute, texture: .init(sampleType: .unfilterableFloat)),
                    .init(binding: 1, visibility: .compute, storageTexture: .init(access: .writeOnly, format: .R32Float)),
                ]))
                let compactionLayout = device.createBindGroupLayout(descriptor: .init(entries: [
                    .init(binding: 0, visibility: .compute, texture: .init(sampleType: .unfilterableFloat)),
                    .init(binding: 1, visibility: .compute, buffer: .init(type: .readOnlyStorage)),
                    .init(binding: 2, visibility: .compute, buffer: .init(type: .readOnlyStorage)),
                    .init(binding: 3, visibility: .compute, buffer: .init(type: .storage)),
                    .init(binding: 4, visibility: .compute, buffer: .init(type: .storage)),
                    .init(binding: 5, visibility: .compute, buffer: .init(type: .uniform)),
                ]))
                func pipeline(_ code: String, name: String, bindings: WebGPU.GPUBindGroupLayout) -> WebGPU.GPUComputePipeline {
                    #if WASM
                        let shader = device.createShaderModule(descriptor: .init(label: name, code: code))
                    #else
                        let shader = device.createShaderModule(descriptor: .init(label: name, nextInChain: WebGPU.GPUShaderSourceWGSL(code: code)))
                    #endif
                    let layout = device.createPipelineLayout(descriptor: .init(bindGroupLayouts: [bindings]))
                    return device.createComputePipeline(descriptor: .init(label: name, layout: layout, compute: .init(module: shader, entryPoint: "main")))
                }
                return Pipelines(
                    reductionLayout: reductionLayout, compactionLayout: compactionLayout,
                    copy: pipeline(WGPUVisibilityShaders.copy, name: "Hi-Z copy", bindings: reductionLayout),
                    reduce: pipeline(WGPUVisibilityShaders.reduce, name: "Hi-Z max reduction", bindings: reductionLayout),
                    compact: pipeline(WGPUVisibilityShaders.compact, name: "Hi-Z instance compaction", bindings: compactionLayout)
                )
            }
            reductionLayout = pipelines.reductionLayout
            compactionLayout = pipelines.compactionLayout
            copy = pipelines.copy
            reduce = pipelines.reduce
            compact = pipelines.compact
            frames = Array(repeating: nil, count: max(1, unsafe RenderEngine.configurations.maxFramesInFlight))
        }

        func encode(
            on command: any CommandBuffer,
            depth: Texture,
            viewProjection: Transform3D,
            instances: any Buffer,
            instanceStride: Int,
            candidates: [GPUVisibilityCandidate],
            draws: [IndexedIndirectArguments]
        ) -> GPUVisibilityOutput? {
            guard let command = command as? WGPUCommandEncoder, let depth = depth.gpuTexture as? WGPUGPUTexture,
                let input = instances as? WGPUBuffer,
                Self.validates(inputLength: input.length, stride: instanceStride, candidates: candidates, draws: draws)
            else { return nil }
            return lock.withLock {
                webGPUDeviceLock.withLock { _ in
                    encodeLocked(command, depth: depth, projection: viewProjection, input: input, stride: instanceStride, candidates: candidates, draws: draws)
                }
            }
        }

        // Stay within baseline WebGPU storage binding limits and validate disjoint output segments before
        // encoding any work. Invalid input leaves the caller's CPU visibility/instance buffers intact.
        static func validates(inputLength: Int, stride: Int, candidates: [GPUVisibilityCandidate], draws: [IndexedIndirectArguments]) -> Bool {
            let limit = 128 * 1_024 * 1_024
            guard stride > 0, stride % 4 == 0, inputLength > 0, inputLength % 4 == 0, inputLength <= limit,
                !candidates.isEmpty, !draws.isEmpty,
                candidates.count <= limit / MemoryLayout<GPUVisibilityCandidate>.stride,
                draws.count <= limit / MemoryLayout<IndexedIndirectArguments>.stride,
                draws.allSatisfy({ $0.firstInstance == 0 })
            else { return false }
            let capacity = inputLength / stride
            var counts: [UInt32: Int] = [:]
            var starts: [UInt32: UInt32] = [:]
            for candidate in candidates {
                guard UInt64(candidate.source) < UInt64(capacity), UInt64(candidate.draw) < UInt64(draws.count),
                    UInt64(candidate.destination) + UInt64(draws[Int(candidate.draw)].instanceCount) <= UInt64(capacity),
                    starts[candidate.draw] == nil || starts[candidate.draw] == candidate.destination
                else { return false }
                starts[candidate.draw] = candidate.destination
                counts[candidate.draw, default: 0] += 1
                if counts[candidate.draw, default: 0] > Int(draws[Int(candidate.draw)].instanceCount) { return false }
            }
            let segments = starts.map { (start: UInt64($0.value), end: UInt64($0.value) + UInt64(draws[Int($0.key)].instanceCount)) }
                .sorted { $0.start < $1.start }
            for index in segments.indices.dropFirst() where segments[index - 1].end > segments[index].start { return false }
            return true
        }

        private func encodeLocked(
            _ command: WGPUCommandEncoder,
            depth: WGPUGPUTexture,
            projection: Transform3D,
            input: WGPUBuffer,
            stride: Int,
            candidates: [GPUVisibilityCandidate],
            draws: [IndexedIndirectArguments]
        ) -> GPUVisibilityOutput? {
            let width = Int(depth.texture.width), height = Int(depth.texture.height)
            guard width > 0, height > 0 else { return nil }
            if size != SizeInt(width: width, height: height) { makePyramid(width: width, height: height) }
            guard let pyramidView, let first = levels.first else { return nil }
            if source !== depth {
                source = depth
                copyGroup = bindGroup(layout: reductionLayout, entries: [.init(binding: 0, textureView: depth.textureView), .init(binding: 1, textureView: first)])
            }
            guard let copyGroup else { return nil }
            frame = (frame + 1) % frames.count
            let candidateBytes = candidates.count * MemoryLayout<GPUVisibilityCandidate>.stride
            let argumentBytes = draws.count * MemoryLayout<IndexedIndirectArguments>.stride
            if frames[frame].map({ Int($0.candidates.size) < candidateBytes || $0.instances.length < input.length || $0.arguments.length < argumentBytes }) ?? true {
                frames[frame] = makeFrame(candidateBytes: candidateBytes, instanceBytes: input.length, argumentBytes: argumentBytes)
            }
            guard var buffers = frames[frame] else { return nil }
            if buffers.input !== input || buffers.group == nil {
                buffers.input = input
                buffers.group = bindGroup(layout: compactionLayout, entries: [
                    .init(binding: 0, textureView: pyramidView),
                    .init(binding: 1, buffer: buffers.candidates, size: UInt64(buffers.candidates.size)),
                    .init(binding: 2, buffer: input.buffer, size: UInt64(input.length)),
                    .init(binding: 3, buffer: buffers.instances.buffer, size: UInt64(buffers.instances.length)),
                    .init(binding: 4, buffer: buffers.arguments.buffer, size: UInt64(buffers.arguments.length)),
                    .init(binding: 5, buffer: buffers.constants, size: UInt64(MemoryLayout<View>.stride)),
                ])
                frames[frame] = buffers
            }
            guard let group = buffers.group else { return nil }
            var arguments = draws
            for index in arguments.indices { arguments[index].instanceCount = 0 }
            write(candidates, to: buffers.candidates)
            write(arguments, to: buffers.arguments.buffer)
            var view = View(projection: projection, width: UInt32(width), height: UInt32(height), count: UInt32(candidates.count), words: UInt32(stride / 4))
            unsafe withUnsafeBytes(of: &view) { bytes in
                unsafe context.device.queue.writeBuffer(buffer: buffers.constants, bufferOffset: 0, data: bytes)
            }
            // Each dispatch is a separate pass: WebGPU supplies storage-write -> texture-read transitions.
            dispatch(on: command, pipeline: copy, group: copyGroup, x: (width + 7) / 8, y: (height + 7) / 8)
            for (index, reduction) in reductions.enumerated() {
                dispatch(on: command, pipeline: reduce, group: reduction, x: (max(1, width >> (index + 1)) + 7) / 8, y: (max(1, height >> (index + 1)) + 7) / 8)
            }
            let groups = (candidates.count + 63) / 64
            let columns = min(groups, 65_535)
            dispatch(on: command, pipeline: compact, group: group, x: columns, y: (groups + columns - 1) / columns)
            return GPUVisibilityOutput(instances: buffers.instances, arguments: buffers.arguments, drawCount: draws.count)
        }

        private func makePyramid(width: Int, height: Int) {
            let count = Int.bitWidth - max(width, height).leadingZeroBitCount
            let texture = context.device.createTexture(descriptor: .init(
                label: "Hi-Z max depth", usage: [.textureBinding, .storageBinding],
                size: .init(width: UInt32(width), height: UInt32(height), depthOrArrayLayers: 1),
                format: .R32Float, mipLevelCount: UInt32(count)
            ))
            pyramid = texture
            pyramidView = texture.createView(descriptor: nil as WebGPU.GPUTextureViewDescriptor?)
            levels = (0..<count).map { level in
                #if WASM
                    // Fill optional enum/count fields: BridgeJS emits nil as null, which WebGPU rejects.
                    texture.createView(descriptor: .init(
                        format: .R32Float, dimension: ._2D, baseMipLevel: level, mipLevelCount: 1, baseArrayLayer: 0, arrayLayerCount: 1
                    ))
                #else
                    texture.createView(descriptor: .init(baseMipLevel: UInt32(level), mipLevelCount: 1))
                #endif
            }
            reductions = (1..<count).map { level in
                bindGroup(layout: reductionLayout, entries: [.init(binding: 0, textureView: levels[level - 1]), .init(binding: 1, textureView: levels[level])])
            }
            size = SizeInt(width: width, height: height)
            source = nil
            copyGroup = nil
            for index in frames.indices { frames[index]?.group = nil }
        }

        private func makeFrame(candidateBytes: Int, instanceBytes: Int, argumentBytes: Int) -> Frame? {
            let device = context.device
            // Swan returns optional handles; the browser binding returns concrete
            // handles and reports allocation/validation failure through WebGPU.
            let candidates: WebGPU.GPUBuffer? = device.createBuffer(descriptor: .init(usage: [.storage, .copyDst], size: UInt64(candidateBytes)))
            let constants: WebGPU.GPUBuffer? = device.createBuffer(descriptor: .init(usage: [.uniform, .copyDst], size: UInt64(MemoryLayout<View>.stride)))
            let instances: WebGPU.GPUBuffer? = device.createBuffer(descriptor: .init(usage: [.storage, .vertex, .copySrc], size: UInt64(instanceBytes)))
            let arguments: WebGPU.GPUBuffer? = device.createBuffer(descriptor: .init(usage: [.storage, .indirect, .copyDst, .copySrc], size: UInt64(argumentBytes)))
            guard let candidates, let constants, let instances, let arguments else { return nil }
            return Frame(
                candidates: candidates, constants: constants,
                instances: WGPUBuffer(buffer: instances, device: device, instance: context.instance),
                arguments: WGPUBuffer(buffer: arguments, device: device, instance: context.instance)
            )
        }

        private func write<T>(_ values: [T], to buffer: WebGPU.GPUBuffer) {
            unsafe values.withUnsafeBytes { bytes in
                unsafe context.device.queue.writeBuffer(buffer: buffer, bufferOffset: 0, data: bytes)
            }
        }

        private func bindGroup(layout: WebGPU.GPUBindGroupLayout, entries: [VisibilityBinding]) -> WebGPU.GPUBindGroup {
            #if WASM
                context.device.createBindGroup(layout: layout, entries: entries)
            #else
                context.device.createBindGroup(descriptor: .init(layout: layout, entries: entries))
            #endif
        }

        private func dispatch(on command: WGPUCommandEncoder, pipeline: WebGPU.GPUComputePipeline, group: WebGPU.GPUBindGroup, x: Int, y: Int) {
            let pass = command.commandEncoder.beginComputePass(descriptor: nil as WebGPU.GPUComputePassDescriptor?)
            pass.setPipeline(pipeline: pipeline)
            pass.setBindGroup(groupIndex: 0, group: group, dynamicOffsets: [])
            pass.dispatchWorkgroups(workgroupCountX: UInt32(x), workgroupCountY: UInt32(y), workgroupCountZ: 1)
            pass.end()
        }
    }
#endif
