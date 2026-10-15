import AdaAssets
import AdaECS
@_spi(Internal) import AdaRender
import AdaUtils
import Math

/// Draws ``DebugDraw3D`` lines over the final 3D image.
///
/// Runs after ``DebugView3DRenderNode`` and before 2D/UI. Depth-tested lines use the scene depth the main
/// pass wrote (the upscaled output depth when temporal upscaling is active); the rest draw on top. A frame
/// with no queued lines records no GPU work.
public struct DebugDraw3DRenderNode: RenderNode {
    public static let name: RenderNodeLabel = "Main3D.DebugDraw"

    @Query<Entity, Camera, RenderViewTarget, GlobalViewUniform, ExtractedCameraSource> private var views
    @Res<ExtractedDebugLines3D> private var extracted
    @ResMut<DebugDraw3DResources> private var resources
    @Res<RenderDeviceHandler> private var device
    @Res<Render3DPerformanceMetrics?> private var metrics
    private let notifiesCompletion: Bool

    public init(notifiesCompletion: Bool = true) { self.notifiesCompletion = notifiesCompletion }

    public func update(from world: World) {
        views.update(from: world)
        _extracted.update(from: world)
        _resources.update(from: world)
        _device.update(from: world)
        _metrics.update(from: world)
    }

    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity, !extracted.lines.isEmpty else {
            return []
        }
        var submitted: CommandBuffer?
        views.forEach { entity, camera, target, uniform, _ in
            guard entity == view, let color = target.mainTexture,
                let depth = target.temporalUpscalingActive ? target.temporalOutputDepthTexture : target.depthTexture
            else { return }
            let ranges = resources.prepare(lines: extracted.lines, device: device.renderDevice)
            guard ranges.testedCount + ranges.overlayCount > 0 else { return }
            let command = renderContext.commandQueue.makeCommandBuffer()
            command.label = "Debug Draw 3D"
            let pass = command.beginRenderPass(RenderPassDescriptor(
                label: "Debug Draw 3D",
                colorAttachments: [.init(texture: color, operation: .init(loadAction: .load, storeAction: .store))],
                depthStencilAttachment: .init(
                    texture: depth,
                    depthOperation: .init(loadAction: .load, storeAction: .store),
                    stencilOperation: .init(loadAction: .load, storeAction: .store)
                )
            ))
            pass.setVertexBuffer(uniform, slot: GlobalBufferIndex.viewUniform)
            pass.setViewport(target.temporalUpscalingActive ? Rect(x: 0, y: 0, width: Float(color.size.width), height: Float(color.size.height)) : camera.viewport.rect)
            pass.setVertexBuffer(resources.vertices, offset: 0, slot: 0)
            pass.setIndexBuffer(resources.indices, indexFormat: .uInt32)
            if ranges.testedCount > 0 {
                pass.setRenderPipelineState(resources.pipeline(depthTested: true, device: device.renderDevice))
                pass.drawIndexed(indexCount: ranges.testedCount * 2, indexBufferOffset: 0, instanceCount: 1)
            }
            if ranges.overlayCount > 0 {
                pass.setRenderPipelineState(resources.pipeline(depthTested: false, device: device.renderDevice))
                pass.drawIndexed(indexCount: ranges.overlayCount * 2, indexBufferOffset: ranges.testedCount * 2 * MemoryLayout<UInt32>.stride, instanceCount: 1)
            }
            pass.endRenderPass()
            if notifiesCompletion, let output = target.outputTexture, output === color {
                command.addCompletedHandler { [output] in output.notifyRenderCompleted() }
            }
            if let metrics {
                command.addCompletedTimingHandler { metrics.record(pass: "debugDraw", seconds: $0) }
            }
            submitted = command
        }
        if let submitted {
            if let metrics { await metrics.commit(submitted) } else { submitted.commit() }
        }
        return []
    }
}

/// Reusable vertex/index storage and the two line pipelines for ``DebugDraw3DRenderNode``.
struct DebugDraw3DResources: Resource {
    struct Ranges {
        var testedCount: Int
        var overlayCount: Int
    }

    var vertices = BufferData<LineVertexData>(label: "DebugDraw3D_Vertices", elements: [])
    var indices = BufferData<UInt32>(label: "DebugDraw3D_Indices", elements: [])
    private var lines = RenderPipelines(configurator: LinePipeline())
    private var tested: RenderPipeline?
    private var overlay: RenderPipeline?

    /// Rebuilds the buffers with depth-tested segments first, then overlay segments.
    mutating func prepare(lines: [DebugDraw3D.Line], device: RenderDevice) -> Ranges {
        vertices.elements.removeAll(keepingCapacity: true)
        indices.elements.removeAll(keepingCapacity: true)
        var counts = Ranges(testedCount: 0, overlayCount: 0)
        for pass in [true, false] {
            for line in lines where line.depthTested == pass {
                let base = UInt32(vertices.count)
                vertices.append(LineVertexData(position: line.start, color: line.color, lineWidth: 1))
                vertices.append(LineVertexData(position: line.end, color: line.color, lineWidth: 1))
                indices.append(base)
                indices.append(base + 1)
                if pass { counts.testedCount += 1 } else { counts.overlayCount += 1 }
            }
        }
        if !lines.isEmpty {
            vertices.write(to: device)
            indices.write(to: device)
        }
        return counts
    }

    mutating func pipeline(depthTested: Bool, device: RenderDevice) -> RenderPipeline {
        if let cached = depthTested ? tested : overlay {
            return cached
        }
        var descriptor = lines.pipeline(device: device).descriptor
        descriptor.debugName = depthTested ? "Debug Draw 3D (depth tested)" : "Debug Draw 3D (overlay)"
        descriptor.depthPixelFormat = .depth_32f_stencil8
        // Backends read only the compare operator, not `isDepthTestEnabled`, so overlay lines use `.always`.
        descriptor.depthStencilDescriptor = DepthStencilDescriptor(
            isDepthTestEnabled: depthTested,
            isDepthWriteEnabled: false,
            depthCompareOperator: depthTested ? .lessOrEqual : .always
        )
        let result = device.createRenderPipeline(from: descriptor)
        if depthTested { tested = result } else { overlay = result }
        return result
    }
}
