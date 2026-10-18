import AdaAssets
import AdaECS
@_spi(Internal) import AdaRender
import AdaUtils
import Math

/// Marches the primary directional light through the fog medium at half resolution and stores the in-scattered light.
///
/// Runs after the main pass and before the environment composite, which adds the result to the frame in linear HDR.
/// A camera without active volumetric fog, or one showing a full-screen debug view, records no GPU work and holds
/// no texture.
public struct VolumetricFog3DRenderNode: RenderNode {
    public static let name: RenderNodeLabel = "Main3D.VolumetricFog"

    @Query<Entity, Camera, RenderViewTarget, GlobalViewUniform, ExtractedCameraSource> private var views
    @Res<ExtractedEnvironment3D> private var environments
    @Res<ExtractedLighting3D> private var lighting
    @ResMut<VolumetricFog3DViews> private var volumetric
    @Res<RenderDeviceHandler> private var device
    @Res<Render3DPerformanceMetrics?> private var metrics

    public init() {}

    public func update(from world: World) {
        views.update(from: world)
        _environments.update(from: world)
        _lighting.update(from: world)
        _volumetric.update(from: world)
        _device.update(from: world)
        _metrics.update(from: world)
        var activeViews: [Entity.ID] = []
        views.forEach { _, _, _, _, source in activeViews.append(source.entityId) }
        volumetric.retainViews(activeViews)
    }

    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }
        let shadow = context.world.getResource(DirectionalShadow3D.self)
        var submitted: CommandBuffer?
        views.forEach { entity, camera, target, viewUniform, source in
            guard entity == view else {
                return
            }
            guard let environment = environments.environments[source.entityId], environment.fog.volumetricActive,
                !environment.debugView.replacesFinalImage, let sun = lighting.directionalLight,
                target.rendering3DUsesEnvironmentTargets, let position = target.viewPositionMetallic3DTexture
            else {
                volumetric.discard(view: source.entityId)
                return
            }
            let fog = environment.fog.sanitized
            let settings = fog.volumetric
            let output = volumetric.output(view: source.entityId, fullSize: position.size, scaleFactor: position.scaleFactor)
            let shadowsEnabled = shadow.map { $0.isEnabled && sun.castsShadows && $0.colorTexture != nil } ?? false
            let atlas = shadow?.colorTexture?.size ?? SizeInt(width: 1024, height: 1024)
            let jittered = temporalViewUniform(viewUniform, target: target)
            let constants = volumetric.uniform.write(
                VolumetricFog3DUniform(
                    inverseView: viewUniform.viewMatrix.inverse,
                    inverseProjection: jittered.projectionMatrix.inverse,
                    shadowViewProjection0: shadow?.viewProjection ?? .identity,
                    shadowViewProjection1: shadow?.viewProjection1 ?? .identity,
                    shadowViewProjection2: shadow?.viewProjection2 ?? .identity,
                    cascadeSplits: shadow?.cascadeSplits ?? [1000, 1000, 1000, 1],
                    shadowAtlas: Vector4(
                        1 / Float(max(atlas.width, 1)),
                        1 / Float(max(atlas.height, 1)),
                        max(0, sun.shadowBias),
                        shadowsEnabled ? 1 : 0
                    ),
                    sunDirection: Vector4(sun.directionToLight.normalized, settings.anisotropy),
                    sunRadiance: Vector4(sun.radiance * (sun.intensity * settings.intensity), 0),
                    medium: Vector4(fog.density, fog.heightFalloff, fog.baseHeight, fog.startDistance),
                    march: Vector4(Float(settings.steps), settings.maxDistance, 0, 0)
                ),
                view: source.entityId,
                device: device.renderDevice
            )
            let command = renderContext.commandQueue.makeCommandBuffer()
            command.label = "Volumetric Fog 3D"
            let pass = command.beginRenderPass(RenderPassDescriptor(
                label: "Volumetric Fog 3D",
                colorAttachments: [.init(texture: output, operation: .init(loadAction: .clear, storeAction: .store), clearColor: .black)],
                depthStencilAttachment: nil
            ))
            pass.setViewport(Rect(x: 0, y: 0, width: Float(output.size.width), height: Float(output.size.height)))
            pass.setRenderPipelineState(volumetric.pipeline)
            pass.setFragmentBuffer(constants, offset: 0, slot: 4)
            pass.setResourceSet(RenderResourceSet(bindings: [
                .init(binding: 0, shaderStages: .fragment, resource: .texture(position)),
                .init(binding: 1, shaderStages: .fragment, resource: .texture(shadow?.colorTexture ?? Texture2D.whiteTexture)),
                .init(binding: 2, shaderStages: .fragment, resource: .sampler(volumetric.nearest)),
            ]), index: 0)
            pass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            pass.endRenderPass()
            if let metrics {
                command.addCompletedTimingHandler { metrics.record(pass: "volumetricFog", seconds: $0) }
            }
            submitted = command
        }
        if let submitted {
            if let metrics { await metrics.commit(submitted) } else { submitted.commit() }
        }
        return []
    }
}

struct VolumetricFog3DUniform: Sendable {
    var inverseView: Transform3D
    var inverseProjection: Transform3D
    var shadowViewProjection0: Transform3D
    var shadowViewProjection1: Transform3D
    var shadowViewProjection2: Transform3D
    var cascadeSplits: Vector4
    var shadowAtlas: Vector4
    var sunDirection: Vector4
    var sunRadiance: Vector4
    var medium: Vector4
    var march: Vector4
}

/// The light-shaft pipeline and a half-resolution result texture per camera, created only while the effect runs.
struct VolumetricFog3DViews: Resource {
    let pipeline: RenderPipeline
    let nearest: Sampler
    var uniform = FrameUniformCache3D<VolumetricFog3DUniform>()
    private var textures: [Entity.ID: RenderTexture] = [:]
    private var retired: [RenderTexture] = []

    init(device: RenderDevice) {
        let shader = CorePipelineShaders.loadRequiredBundled(at: "Shaders/volumetric_fog_3d.glsl")
        var descriptor = RenderPipelineDescriptor(
            vertex: shader.asset.requiredShader(for: .vertex),
            fragment: shader.asset.getShader(for: .fragment),
            debugName: "Volumetric Fog 3D",
            backfaceCulling: false,
            depthPixelFormat: .none
        )
        descriptor.colorAttachments = [.init(format: .rgba_16f)]
        pipeline = device.createRenderPipeline(from: descriptor)
        nearest = device.createSampler(from: .init(minFilter: .nearest, magFilter: .nearest, mipFilter: .notMipmapped))
    }

    /// The light-shaft texture for `view` if the effect ran for it.
    func output(view: Entity.ID) -> RenderTexture? {
        textures[view]
    }

    /// A texture at half the size of the scene targets, rebuilt when that size changes.
    mutating func output(view: Entity.ID, fullSize: SizeInt, scaleFactor: Float) -> RenderTexture {
        let size = SizeInt(width: max(1, fullSize.width / 2), height: max(1, fullSize.height / 2))
        if let existing = textures[view], existing.size == size {
            return existing
        }
        if let replaced = textures[view] {
            retire(replaced)
        }
        let texture = RenderTexture(size: size, scaleFactor: scaleFactor, format: .rgba_16f, debugLabel: "3D Volumetric Fog")
        textures[view] = texture
        return texture
    }

    mutating func retainViews(_ views: [Entity.ID]) {
        for view in textures.keys where !views.contains(view) {
            discard(view: view)
        }
        uniform.retainViews(views)
    }

    mutating func discard(view: Entity.ID) {
        if let removed = textures.removeValue(forKey: view) {
            retire(removed)
        }
    }

    private mutating func retire(_ texture: RenderTexture) {
        retired.append(texture)
        let limit = max(1, unsafe RenderEngine.configurations.maxFramesInFlight) + 1
        if retired.count > limit {
            retired.removeFirst(retired.count - limit)
        }
    }
}
