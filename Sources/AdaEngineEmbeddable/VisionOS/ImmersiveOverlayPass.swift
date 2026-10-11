#if os(visionOS)
    import AdaUI
    import AdaUtils
    import CompositorServices
    import Math
    import Metal

    /// Adapter for existing AdaUI vector commands; editor shape/style definitions stay in their owning module.
    @available(visionOS 26.0, *)
    @MainActor
    final class ImmersiveOverlayPass {
        private struct Vertex {
            var position: SIMD2<Float>
            var color: SIMD4<Float>
            var depth: Float
        }
        private let pipeline: any MTLRenderPipelineState
        private let depthState: any MTLDepthStencilState
        private let hasTracking: Bool
        private let tessellator = UITessellator()

        init(device: any MTLDevice, colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, tracking: Bool) throws {
            hasTracking = tracking
            let source = "#define HAS_TRACKING \(tracking ? 1 : 0)\n" + Self.shader
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "overlayVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "overlayFragment")
            descriptor.depthAttachmentPixelFormat = depthFormat
            let color = descriptor.colorAttachments[0]
            color?.pixelFormat = colorFormat
            color?.isBlendingEnabled = true
            color?.sourceRGBBlendFactor = .sourceAlpha
            color?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color?.sourceAlphaBlendFactor = .one
            color?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            if tracking { descriptor.colorAttachments[1].pixelFormat = .r16Uint }
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            let depth = MTLDepthStencilDescriptor()
            // Match desktop editor overlays: handles remain legible in front of the selected mesh.
            depth.depthCompareFunction = .always
            depth.isDepthWriteEnabled = false
            guard let state = device.makeDepthStencilState(descriptor: depth) else { throw ImmersiveRendererError.metalResourceUnavailable }
            depthState = state
        }

        func encode(commands: any MTLCommandBuffer, drawable: LayerRenderer.Drawable, eye: Int, drawings: [ImmersiveOverlayDrawing]) {
            guard !drawings.isEmpty, eye < drawable.views.count else {
                return
            }
            let map = drawable.views[eye].textureMap
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.colorTextures[map.textureIndex]
            pass.colorAttachments[0].slice = map.sliceIndex
            pass.colorAttachments[0].loadAction = .load
            pass.colorAttachments[0].storeAction = .store
            pass.depthAttachment.texture = drawable.depthTextures[map.textureIndex]
            pass.depthAttachment.slice = map.sliceIndex
            pass.depthAttachment.loadAction = .load
            pass.depthAttachment.storeAction = .store
            if hasTracking, !drawable.trackingAreasTextures.isEmpty {
                pass.colorAttachments[1].texture = drawable.trackingAreasTextures[map.textureIndex]
                pass.colorAttachments[1].slice = map.sliceIndex
                pass.colorAttachments[1].loadAction = .load
                pass.colorAttachments[1].storeAction = .store
            }
            guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
                return
            }
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setViewport(map.viewport)
            encoder.setCullMode(.none)
            var size = SIMD2<Float>(Float(map.viewport.width), Float(map.viewport.height))
            encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
            for drawing in drawings {
                let vertices = vertices(for: drawing)
                guard !vertices.isEmpty else { continue }
                // makeBuffer copies the array synchronously; the encoder retains the Metal buffer until completion.
                let buffer = vertices.withUnsafeBufferPointer {
                    guard let base = $0.baseAddress else {
                        return nil as (any MTLBuffer)?
                    }
                    return commands.device.makeBuffer(bytes: base, length: $0.count * MemoryLayout<Vertex>.stride)
                }
                guard let buffer else { continue }
                var value: UInt16 = 0
                if hasTracking, let identifier = drawing.trackingIdentifier {
                    let area = drawable.addTrackingArea(identifier: .init(identifier))
                    area.addHoverEffect(.automatic)
                    value = UInt16(area.renderValue.rawValue)
                }
                encoder.setFragmentBytes(&value, length: MemoryLayout<UInt16>.stride, index: 0)
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
            }
            encoder.endEncoding()
        }

        private func vertices(for drawing: ImmersiveOverlayDrawing) -> [Vertex] {
            var output: [Vertex] = []
            // AdaUI tessellation uses Y-up engine coordinates; this pixel overlay uses Y-down.
            func append(_ point: Vector2, _ color: Color) {
                output.append(Vertex(position: SIMD2(point.x, -point.y), color: SIMD4(color.red, color.green, color.blue, color.alpha), depth: 1 - drawing.depth))
            }
            func line(_ a: Vector3, _ b: Vector3, width: Float, color: Color) {
                let delta = Vector2(b.x - a.x, b.y - a.y)
                guard delta.squaredLength > 0.00001 else {
                    return
                }
                let normal = Vector2(-delta.y, delta.x).normalized * width * 0.5
                let start = Vector2(a.x, a.y)
                let end = Vector2(b.x, b.y)
                for point in [start + normal, start - normal, end + normal, end + normal, start - normal, end - normal] { append(point, color) }
            }
            for command in drawing.context.getDrawCommands() {
                switch command {
                case let .drawPath(path, transform, mode):
                    switch mode {
                    case let .stroke(color, style):
                        let mesh = tessellator.tessellatePathStroke(path, lineWidth: style.lineWidth, color: color, transform: transform)
                        for index in stride(from: 0, to: mesh.indices.count - 1, by: 2) {
                            let a = mesh.vertices[Int(mesh.indices[index])]
                            let b = mesh.vertices[Int(mesh.indices[index + 1])]
                            line(a.position, b.position, width: a.lineWidth, color: a.color)
                        }
                    case let .fill(color):
                        let mesh = tessellator.tessellatePathFill(path, color: color, transform: transform)
                        for index in mesh.indices {
                            let vertex = mesh.vertices[Int(index)]
                            append(Vector2(vertex.position.x, vertex.position.y), vertex.color)
                        }
                    case .legacy: break
                    }
                case let .drawQuad(transform, _, color):
                    let mesh = tessellator.tessellateQuad(transform: transform, texture: nil, color: color, textureIndex: 0)
                    for index in tessellator.generateQuadIndices(vertexOffset: 0) {
                        let vertex = mesh[Int(index)]
                        append(Vector2(vertex.position.x, vertex.position.y), vertex.color)
                    }
                case let .drawLine(start, end, width, color): line(start, end, width: width, color: color)
                default: break
                }
            }
            return output
        }

        private static let shader = """
            #include <metal_stdlib>
            using namespace metal;
            struct Vertex { float2 position; float4 color; float depth; };
            struct Out { float4 position [[position]]; float4 color; };
            vertex Out overlayVertex(uint id [[vertex_id]], const device Vertex *vertices [[buffer(0)]], constant float2 &size [[buffer(1)]]) {
                Vertex v = vertices[id];
                return { float4(v.position / size * float2(2, -2) + float2(-1, 1), v.depth, 1), v.color };
            }
            struct Fragment { float4 color [[color(0)]];
            #if HAS_TRACKING
                ushort tracking [[color(1)]];
            #endif
            };
            fragment Fragment overlayFragment(Out in [[stage_in]], constant ushort &tracking [[buffer(0)]]) {
                Fragment out; out.color = in.color;
            #if HAS_TRACKING
                out.tracking = tracking;
            #endif
                return out;
            }
            """
    }
#endif
