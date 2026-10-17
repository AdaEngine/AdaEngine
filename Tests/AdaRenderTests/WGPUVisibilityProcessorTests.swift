#if canImport(WebGPU) && !os(WASI) && !os(Android)
    @_spi(Internal) @testable import AdaRender
    import AdaUtils
    import Foundation
    import Math
    import Testing

    @MainActor
    @Suite("WebGPU Hi-Z visibility", .serialized)
    struct WGPUVisibilityProcessorTests {
        @Test
        func rejectsInvalidAndOverlappingOutputSegments() {
            let candidate = GPUVisibilityCandidate(bounds: nil, draw: 0, source: 0, destination: 0, forceVisible: false)
            let draw = IndexedIndirectArguments(indexCount: 3, instanceCount: 1)
            func valid(_ entries: [GPUVisibilityCandidate], _ draws: [IndexedIndirectArguments] = [draw], stride: Int = 4) -> Bool {
                WGPUVisibilityProcessor.validates(inputLength: 8, stride: stride, candidates: entries, draws: draws)
            }
            #expect(valid([candidate]))
            #expect(!valid([]))
            #expect(!valid([candidate], stride: 3))
            #expect(!valid([candidate, candidate]))
            var invalid = candidate
            invalid.source = 2
            #expect(!valid([invalid]))
            invalid = candidate
            invalid.draw = 1
            #expect(!valid([invalid]))
            #expect(!valid([candidate, invalid], [draw, draw]))
            invalid.destination = 1
            #expect(valid([candidate, invalid], [draw, draw]))
            invalid.destination = UInt32.max
            #expect(!valid([invalid], [draw, draw]))
            var unsupported = draw
            unsupported.firstInstance = 1
            #expect(!valid([candidate], [unsupported]))
        }

        @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_WEBGPU_VISIBILITY_SMOKE"] == "1"))
        func compactsDepthAndRecoversAfterCameraMotionRemovalResizeAndFrameReuse() async throws {
            let device = try WebGPURenderBackend.createBackend().createLocalRenderDevice()
            let processor = try #require(device.createGPUVisibilityProcessor())
            let input = device.createBuffer(label: "Visibility markers", length: 8, options: .storageShared)
            var markers: [UInt32] = [101, 202]
            input.setElements(&markers)
            let hidden = AABB(center: [0, 0, 0.8], halfExtents: [0.02, 0.02, 0.02])
            let front = AABB(center: [0, 0, 0.2], halfExtents: [0.02, 0.02, 0.02])
            let candidates = [
                GPUVisibilityCandidate(bounds: hidden, draw: 0, source: 0, destination: 0, forceVisible: false),
                GPUVisibilityCandidate(bounds: front, draw: 1, source: 1, destination: 1, forceVisible: false),
            ]
            let draws = [IndexedIndirectArguments(indexCount: 3, instanceCount: 1), IndexedIndirectArguments(indexCount: 3, instanceCount: 1)]
            var texture = makeDepth(device, width: 5, height: 3)
            func evaluate(depth: Float, hole: Bool = false, projection: Transform3D = .identity, entries: [GPUVisibilityCandidate] = candidates) async throws -> [UInt32] {
                uploadDepth(depth, hole: hole, to: texture)
                let command = device.createCommandQueue().makeCommandBuffer()
                let output = try #require(processor.encode(
                    on: command, depth: texture, viewProjection: projection, instances: input, instanceStride: 4, candidates: entries, draws: draws
                ))
                command.commit()
                let counts = words(try await output.arguments.readData())
                let values = words(try await output.instances.readData())
                #expect(output.drawCount == 2)
                #expect(counts[0] == 3 && counts[5] == 3)
                if counts[1] != 0 { #expect(values[0] == 101) }
                if counts[6] != 0 { #expect(values[1] == 202) }
                return [counts[1], counts[6]]
            }
            #expect(try await evaluate(depth: 0.4) == [0, 1])
            #expect(try await evaluate(depth: 0.4, projection: Transform3D(translation: [0, 0, -0.7])) == [1, 1])
            #expect(try await evaluate(depth: 1) == [1, 1])
            #expect(try await evaluate(depth: 0.4, hole: true) == [1, 1])
            var force = candidates
            force[0].forceVisible = 1
            #expect(try await evaluate(depth: 0.4, entries: force) == [1, 1])
            var near = candidates
            near[0].minimum.z = -0.01
            #expect(try await evaluate(depth: 0.4, entries: near) == [1, 1])
            var moved = candidates
            moved[0].minimum.z = 0.1
            moved[0].maximum.z = 0.15
            #expect(try await evaluate(depth: 0.4, entries: moved) == [1, 1])
            var invalid = candidates
            invalid[0].minimum.x = .infinity
            #expect(try await evaluate(depth: 0.4, entries: invalid) == [1, 1])
            // Reuse the same processor across ring wraps, replacement textures and a one-pixel pyramid.
            for dimensions in [SizeInt(width: 1, height: 1), [9, 7], [5, 3]] {
                texture = makeDepth(device, width: dimensions.width, height: dimensions.height)
                #expect(try await evaluate(depth: 0.4) == [0, 1])
                #expect(try await evaluate(depth: 1) == [1, 1])
            }
            let other = try #require(device.createGPUVisibilityProcessor())
            let otherDepth = makeDepth(device, width: 5, height: 3)
            uploadDepth(0.4, to: texture)
            uploadDepth(1, to: otherDepth)
            let command = device.createCommandQueue().makeCommandBuffer()
            let firstView = try #require(processor.encode(
                on: command, depth: texture, viewProjection: .identity, instances: input, instanceStride: 4, candidates: candidates, draws: draws
            ))
            let secondView = try #require(other.encode(
                on: command, depth: otherDepth, viewProjection: .identity, instances: input, instanceStride: 4, candidates: candidates, draws: draws
            ))
            command.commit()
            #expect(words(try await firstView.arguments.readData())[1] == 0)
            #expect(words(try await secondView.arguments.readData())[1] == 1)

            // More than one workgroup must compact into a single disjoint segment, including after
            // input-buffer replacement and ring allocation growth. Atomic output order is unspecified.
            var largeMarkers = Array(UInt32(0)..<257)
            let largeInput = device.createBuffer(label: "Grown visibility input", length: largeMarkers.count * 4, options: .storageShared)
            largeInput.setElements(&largeMarkers)
            let largeCandidates = largeMarkers.map { GPUVisibilityCandidate(bounds: nil, draw: 0, source: $0, destination: 0, forceVisible: false) }
            for count in [257, 1, 257, 1, 257] {
                let command = device.createCommandQueue().makeCommandBuffer()
                let output = try #require(processor.encode(
                    on: command, depth: texture, viewProjection: .identity, instances: largeInput, instanceStride: 4,
                    candidates: Array(largeCandidates.prefix(count)), draws: [.init(indexCount: 3, instanceCount: UInt32(count))]
                ))
                command.commit()
                #expect(words(try await output.arguments.readData())[1] == UInt32(count))
                #expect(Array(words(try await output.instances.readData()).prefix(count)).sorted() == Array(largeMarkers.prefix(count)))
            }
        }

        @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_WEBGPU_VISIBILITY_SMOKE"] == "1"))
        func rendersCompactedInstancesAndZeroCountIndexedIndirectDraws() async throws {
            let device = try WebGPURenderBackend.createBackend().createLocalRenderDevice()
            let processor = try #require(device.createGPUVisibilityProcessor())
            let input = device.createBuffer(label: "Visibility colors", length: 48, options: .storageShared)
            var colors: [Vector4] = [[1, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1, 1]]
            input.setElements(&colors)
            let hidden = AABB(center: [0, 0, 0.8], halfExtents: [0.02, 0.02, 0.02])
            let front = AABB(center: [0, 0, 0.2], halfExtents: [0.02, 0.02, 0.02])
            let candidates = [
                GPUVisibilityCandidate(bounds: hidden, draw: 0, source: 0, destination: 0, forceVisible: false),
                GPUVisibilityCandidate(bounds: front, draw: 0, source: 1, destination: 0, forceVisible: false),
                GPUVisibilityCandidate(bounds: front, draw: 1, source: 2, destination: 2, forceVisible: false),
            ]
            let draws = [
                IndexedIndirectArguments(indexCount: 3, instanceCount: 2, firstIndex: 1, baseVertex: -1),
                IndexedIndirectArguments(indexCount: 3, instanceCount: 1, firstIndex: 1, baseVertex: -1),
            ]
            let depth = makeDepth(device, width: 5, height: 3)
            let pipeline = try makePipeline(device)
            let indices: [UInt32] = [99, 1, 2, 3]
            let indexBuffer = unsafe try indices.withUnsafeBytes { bytes in
                let pointer = try #require(bytes.baseAddress)
                return unsafe device.createIndexBuffer(format: .uInt32, bytes: pointer, length: bytes.count)
            }
            let target = Texture2D(
                gpuTexture: device.createTexture(from: .init(width: 8, height: 4, pixelFormat: .rgba8, textureUsage: [.renderTarget, .read], textureType: .texture2D)),
                sampler: device.createSampler(from: .init()), size: [8, 4]
            )
            for z: Float in [0.4, 0.1] {
                uploadDepth(z, to: depth)
                let command = device.createCommandQueue().makeCommandBuffer()
                let output = try #require(processor.encode(
                    on: command, depth: depth, viewProjection: .identity, instances: input, instanceStride: 16, candidates: candidates, draws: draws
                ))
                var compacted = BufferData<Vector4>(elements: [])
                compacted.buffer = output.instances
                let pass = command.beginRenderPass(.init(colorAttachments: [
                    .init(texture: target, operation: .init(loadAction: .clear, storeAction: .store), clearColor: .black)
                ]))
                pass.setRenderPipelineState(pipeline)
                pass.setViewport(Rect(x: 0, y: 0, width: 8, height: 4))
                pass.setIndexBuffer(indexBuffer, offset: 0)
                for draw in 0..<2 {
                    pass.setVertexBuffer(compacted, offset: draw == 0 ? 0 : 32, slot: 0)
                    pass.setScissorRect(Rect(x: Float(draw * 4), y: 0, width: 4, height: 4))
                    let encoded = pass.drawIndexedIndirect(arguments: output.arguments, offset: draw * 20)
                    #expect(encoded)
                }
                let misaligned = pass.drawIndexedIndirect(arguments: output.arguments, offset: 1)
                let outOfBounds = pass.drawIndexedIndirect(arguments: output.arguments, offset: output.arguments.length)
                #expect(!misaligned)
                #expect(!outOfBounds)
                pass.endRenderPass()
                command.commit()
                let image = try #require(try await device.readImage(from: target))
                #expect(image.getPixel(x: 1, y: 1) == (z == 0.4 ? .green : .black))
                #expect(image.getPixel(x: 6, y: 1) == (z == 0.4 ? .blue : .black))
            }
        }

        private func makeDepth(_ device: any RenderDevice, width: Int, height: Int) -> Texture2D {
            Texture2D(
                gpuTexture: device.createTexture(from: .init(width: width, height: height, pixelFormat: .rgba_32f, textureUsage: [.read], textureType: .texture2D)),
                sampler: device.createSampler(from: .init()), size: SizeInt(width: width, height: height)
            )
        }

        private func uploadDepth(_ z: Float, hole: Bool = false, to texture: Texture2D) {
            let width = texture.size.width, height = texture.size.height
            var pixels = [Float](repeating: z, count: width * height * 4)
            if hole { pixels[(width * height - 1) * 4] = 1 }
            unsafe pixels.withUnsafeBytes { bytes in
                if let pointer = bytes.baseAddress {
                    unsafe texture.gpuTexture.replaceRegion(RectInt(x: 0, y: 0, width: width, height: height), mipmapLevel: 0, withBytes: pointer, bytesPerRow: width * 16)
                }
            }
        }

        private func words(_ data: Data) -> [UInt32] {
            data.withUnsafeBytes { raw in
                stride(from: 0, to: raw.count, by: 4).map { unsafe raw.loadUnaligned(fromByteOffset: $0, as: UInt32.self) }
            }
        }

        private func makePipeline(_ device: any RenderDevice) throws -> any RenderPipeline {
            let source = """
                struct Vertex { @builtin(position) position: vec4f, @location(0) color: vec4f }
                @vertex fn vertex(@builtin(vertex_index) i: u32, @location(0) color: vec4f) -> Vertex {
                    let positions = array<vec2f, 3>(vec2f(-1, -1), vec2f(3, -1), vec2f(-1, 3));
                    return Vertex(vec4f(positions[i], 0, 1), color);
                }
                @fragment fn fragment(v: Vertex) -> @location(0) vec4f { return v.color; }
                """
            let vertex = Shader(source: source, entryPoint: "vertex", stage: .vertex)
            let fragment = Shader(source: source, entryPoint: "fragment", stage: .fragment)
            vertex.compiledShader = try device.compileShader(from: vertex)
            fragment.compiledShader = try device.compileShader(from: fragment)
            var descriptor = RenderPipelineDescriptor(
                vertex: vertex, fragment: fragment, debugName: "Visibility indirect draw",
                backfaceCulling: false, colorAttachments: [.init(format: .rgba8)]
            )
            descriptor.vertexDescriptor.attributes[0] = .init(name: "color", offset: 0, bufferIndex: 0, format: .vector4)
            descriptor.vertexDescriptor.layouts[0] = .init(stride: 16, stepFunction: .perInstance)
            return device.createRenderPipeline(from: descriptor)
        }
    }
#endif
