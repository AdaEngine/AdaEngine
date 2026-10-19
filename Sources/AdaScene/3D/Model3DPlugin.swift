//
//  Model3DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaApp
import AdaCorePipelines
import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import AdaUtils
import Math

/// Plugin for extracting 3D models from scene to RenderWorld.
public struct Model3DPlugin: Plugin {
    public init() {}

    public func setup(in app: AppWorlds) {
        // Model markers also work when hosts compose this plugin without DefaultPlugins.
        if !app.main.supportsEventDelivery {
            app.insertResource(HandledEvents())
            app.addSystem(EventsUpdateSystem.self, on: .preUpdate)
        }
        Model3DSource.registerComponent()
        Model3DSourceState.registerComponent()
        ModelAnimationPlayback3DComponent.registerComponent()
        app.addSystem(ModelAnimationPlayback3DSystem.self, on: .postUpdate)
        app.addSystem(Model3DSourceSystem.self, on: .preUpdate)
        Mesh3DComponent.registerComponent()
        MeshLOD3DComponent.registerComponent()
        DirectionalLightComponent.registerComponent()
        PointLightComponent.registerComponent()
        SpotLightComponent.registerComponent()
        BillboardComponent.registerComponent()
        ModelAnimation3DComponent.registerComponent()
        ModelNode3DComponent.registerComponent()
        SkinnedMesh3DComponent.registerComponent()
        app.addSystem(SkeletalAnimation3DSystem.self, on: .postUpdate)
        VoxelAnimationPlayback3DComponent.registerComponent()
        VoxelTransformAnimation3DComponent.registerComponent()
        VoxelShapeAnimation3DComponent.registerComponent()
        app.addSystem(VoxelAnimation3DSystem.self, on: .postUpdate)
        VoxelWorld3DComponent.registerComponent()
        VoxelChunk3DComponent.registerComponent()
        app.addSystem(VoxelWorldMeshing3DSystem.self, on: .preUpdate)

        app.addSystem(BillboardSystem.self, on: .update)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .insertResource(ExtractedLighting3D())
            .insertResource(ExtractedMesh3DSources())
            .insertResource(AnimatedBounds3D())
            .insertResource(Active3DInstanceBuffers())
            .insertResource(Skinning3DUniforms())
            .insertResource(Morph3DUniforms())
            .insertResource(PBR3DUniforms())
            .insertResource(RenderPipelines(configurator: PBR3DPipeline()))
            .insertResource(RenderPipelines(configurator: Flat3DPipeline()))
            .insertResource(Model3DDrawPass())
            .addSystem(ExtractDirectionalLight3DSystem.self, on: .extract)
            .addSystem(ExtractModel3DSystem.self, on: .extract)
    }
}

@System
func ExtractModel3D(
    _ query: Extract<Query<Entity,
    Mesh3DComponent,
    GlobalTransform>>,
    _ lods: Extract<Query<Entity,
    MeshLOD3DComponent>>,
    _ visibilityAccess: Extract<Query<Entity,
    Visibility>>,
    _ noCullingAccess: Extract<Query<Entity,
    NoFrustumCulling>>,
    _ hierarchyAccess: Extract<Query<Entity,
    RelationshipComponent>>,
    _ skins: Extract<Query<Entity,
    SkinnedMesh3DComponent>>,
    _ morphs: Extract<Query<Entity,
    MorphWeights3DComponent>>,
    _ morphUniforms: ResMut<Morph3DUniforms>,
    _ sources: ResMut<ExtractedMesh3DSources>,
    _ animatedBounds: ResMut<AnimatedBounds3D>,
    _ skinningUniforms: ResMut<Skinning3DUniforms>,
    _ materialUniforms: ResMut<PBR3DUniforms>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ drawPass: Res<Model3DDrawPass>
) {
    animatedBounds.wrappedValue.beginFrame()
    var previousTransforms: [Entity.ID: Transform3D] = [:]
    for source in sources.meshes { previousTransforms[source.entity] = source.transform }
    sources.meshes.removeAll(keepingCapacity: true)
    // These typed queries declare all optional/hierarchical component reads without requiring them on a mesh.
    _ = visibilityAccess.wrappedValue
    _ = noCullingAccess.wrappedValue
    _ = hierarchyAccess.wrappedValue
    var lodByEntity: [Entity.ID: MeshLOD3DComponent] = [:]
    lods.wrappedValue.forEach { entity, lod in lodByEntity[entity.id] = lod }
    var posedBounds: [Entity.ID: AABB] = [:]
    skinningUniforms.wrappedValue.beginFrame(device: renderDevice.renderDevice)
    morphUniforms.wrappedValue.beginFrame()
    var morphByEntity: [Entity.ID: [Float]] = [:]
    morphs.wrappedValue.forEach { entity, morph in morphByEntity[entity.id] = morph.weights }
    // Morph deltas are applied before skinning, so a joint matrix that scales also scales the displacement.
    var skinScale: [Entity.ID: Float] = [:]
    skins.wrappedValue.forEach { entity, skin in
        _ = skinningUniforms.wrappedValue.write(skin.matrices, for: entity.id, device: renderDevice.renderDevice, revision: .init(id: skin.paletteID, generation: skin.poseGeneration))
        if let mesh = entity.components[Mesh3DComponent.self]?.mesh {
            let lod = lodByEntity[entity.id]
            let meshes = lod?.skeletonCompatible == true ? [mesh] + (lod?.alternatives ?? []) : [mesh]
            let bounds = meshes.count > 1
                ? animatedBounds.wrappedValue.bounds(meshes: meshes, matrices: skin.matrices)
                : animatedBounds.wrappedValue.bounds(mesh: mesh, matrices: skin.matrices)
            posedBounds[entity.id] = bounds
        }
        var largest: Float = 1
        for matrix in skin.matrices {
            largest = max(largest, matrix.x.xyz.length, matrix.y.xyz.length, matrix.z.xyz.length)
        }
        skinScale[entity.id] = largest
    }
    materialUniforms.wrappedValue.beginFrame()

    // Many mesh parts share the same model ancestors. Resolve each ancestor's
    // visibility once per extraction, including hidden parents without meshes.
    var hiddenHierarchy: [Entity.ID: Bool] = [:]
    func isHidden(_ entity: Entity) -> Bool {
        if let hidden = hiddenHierarchy[entity.id] { return hidden }
        let hidden = entity.components[Visibility.self] == .hidden || entity.parent.map(isHidden) == true
        hiddenHierarchy[entity.id] = hidden
        return hidden
    }

    query.wrappedValue.forEach { entity, mesh3d, transform in
        let lod = lodByEntity[entity.id]
        if isHidden(entity) { return }
        let noCulling = entity.components[NoFrustumCulling.self]
        let mesh = mesh3d.mesh
        let palette = skinningUniforms.wrappedValue.buffer(for: entity.id)
        var localBounds: AABB? = palette == nil ? mesh.bounds : posedBounds[entity.id]
        if palette == nil, let lod {
            for level in lod.alternatives { localBounds = localBounds.map { AABB(min: min($0.min, level.bounds.min), max: max($0.max, level.bounds.max)) } ?? level.bounds }
        }
        // Weights move vertices past the rest-pose bounds, so culling and shadow bounds grow by the most the weights can displace.
        var morphBuffers: [UInt64: any UniformBuffer] = [:]
        if mesh.hasMorphTargets, let weights = morphByEntity[entity.id] {
            let written = morphUniforms.wrappedValue.write(weights: weights, mesh: mesh, for: entity.id, device: renderDevice.renderDevice)
            var displacement: Float = 0
            for (key, buffer) in written {
                morphBuffers[Mesh3DRenderSource.morphKey(model: key.model, part: key.part)] = buffer
                if let set = mesh.models[key.model].parts[key.part].morphTargets {
                    displacement = max(displacement, set.maximumDisplacement(for: weights))
                }
            }
            if displacement > 0, let bounds = localBounds {
                let growth = Vector3.one * (displacement * (skinScale[entity.id] ?? 1))
                localBounds = AABB(min: bounds.min - growth, max: bounds.max + growth)
            }
        }
        sources.meshes.append(Mesh3DRenderSource(
            entity: entity.id,
            drawPass: drawPass.wrappedValue,
            mesh: mesh,
            materials: mesh3d.materials,
            transform: transform.matrix,
            bounds: localBounds.map { MeshVisibility3DMath.transformed($0, by: transform.matrix) },
            // Level-of-detail meshes have their own vertices, which the morph deltas do not address.
            alternatives: morphBuffers.isEmpty && (palette == nil || lod?.skeletonCompatible == true && localBounds != nil) ? lod?.alternatives ?? [] : [],
            thresholds: lod?.screenThresholds ?? [],
            hysteresis: lod?.hysteresis ?? 0.15,
            maximumDistance: lod?.maximumDistance,
            fadeDistance: lod?.fadeDistance ?? 4,
            forceVisible: noCulling != nil,
            castShadows: mesh3d.castShadows,
            receiveShadows: mesh3d.receiveShadows,
            skinningBuffer: palette,
            previousTransform: previousTransforms[entity.id],
            morphBuffers: morphBuffers
        ))
    }

    animatedBounds.wrappedValue.finishFrame()
}

public final class Model3DDrawPass: DrawPass, @unchecked Sendable {
    private static let flatNormalTexture = Texture2D(
        image: Image(width: 1, height: 1, color: Color(red: 0.5, green: 0.5, blue: 1))
    )
    private static let blackTexture = Texture2D(
        image: Image(width: 1, height: 1, color: .black)
    )

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Opaque3DRenderItem
    ) throws {
        let part = item.mesh.models[item.modelIndex].parts[item.partIndex]
        let renderDevice = world.getResource(RenderDeviceHandler.self)?.renderDevice
        guard let renderDevice else {
            return
        }

        let isMotion = world.getResource(ActiveMotion3DPass.self)?.isEnabled == true
        let morphed = item.morphBuffer != nil && part.morphTargets != nil
        let configuration = PBR3DConfiguration(
            vertex: part.vertexDescriptor,
            blended: (item.material as? PBRMaterial)?.alphaMode == .blend,
            temporalDepth: view.components[RenderViewTarget.self]?.temporalUpscalingActive == true,
            // The motion shader has no shading layers, so its pipelines are not split by them.
            features: (isMotion ? [] : (item.material as? PBRMaterial)?.shaderFeatures ?? []).union(morphed ? .morph : [])
        )
        let pipeline: any RenderPipeline
        if isMotion {
            let pipelines = world.getRefResource(RenderPipelines<Motion3DPipeline>.self)
            pipeline = pipelines.wrappedValue.pipeline(for: configuration, device: renderDevice)
        } else {
            let pipelines = world.getRefResource(RenderPipelines<PBR3DPipeline>.self)
            pipeline = pipelines.wrappedValue.pipeline(for: configuration, device: renderDevice)
        }
        // Instance data of the view being drawn, written by VisibleMesh3DLists and activated by the render node.
        let active = world.getResource(Active3DInstanceBuffers.self)
        guard
            let batchRange = item.batchRange,
            let instances = active?.instances,
            let defaultVertexData = active?.defaults
        else {
            return
        }

        guard let palette = item.skinningBuffer ?? world.getResource(Skinning3DUniforms.self)?.identityBuffer else {
            return
        }
        guard let materialBuffer = world.getResource(PBR3DUniforms.self)?.buffer(for: item.material) else {
            return
        }
        let pbrMaterial = item.material as? PBRMaterial
        let baseColorTexture = pbrMaterial?.baseColorTexture ?? Texture2D.whiteTexture
        let metallicRoughnessTexture = pbrMaterial?.metallicRoughnessTexture ?? Texture2D.whiteTexture
        let normalTexture = pbrMaterial?.normalTexture ?? Self.flatNormalTexture
        let emissiveTexture = pbrMaterial?.emissiveTexture ?? Texture2D.whiteTexture
        let heightTexture = pbrMaterial?.heightTexture ?? Texture2D.whiteTexture
        // The main shader variant declares exactly the layer textures the material has (see PBRMaterial.shaderFeatures).
        var layerBindings: [RenderResourceSet.Binding] = []
        if morphed, let morphBuffer = item.morphBuffer, let morphSet = part.morphTargets {
            layerBindings.append(.init(binding: Morph3DUniforms.binding, shaderStages: .vertex, resource: .uniformBuffer(morphBuffer, offset: 0)))
            layerBindings.append(.init(binding: Morph3DUniforms.textureBinding, shaderStages: .vertex, resource: .texture(morphSet.deltaTexture)))
        }
        if !isMotion, let pbrMaterial {
            let features = pbrMaterial.shaderFeatures
            for kind in PBRLayerTexture.allCases where features.contains(kind.feature) {
                if let layer = pbrMaterial.layerTextures[kind] {
                    layerBindings.append(.init(binding: kind.binding, shaderStages: .fragment, resource: .texture(layer.texture)))
                }
            }
        }

        if isMotion {
            let previous = world.getResource(Skinning3DUniforms.self)?.previousBuffer(for: item.entity) ?? palette
            renderEncoder.setResourceSet(RenderResourceSet(bindings: [
                .init(binding: 24, shaderStages: .vertex, resource: .uniformBuffer(previous, offset: 0)),
            ]), index: 0)
        }
        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setResourceSet(
            RenderResourceSet(
                bindings: [
                    .init(binding: PBR3DUniforms.binding, shaderStages: .fragment, resource: .uniformBuffer(materialBuffer, offset: 0)),
                    .init(binding: 16, shaderStages: .fragment, resource: .texture(pbrMaterial?.occlusionTexture ?? Texture2D.whiteTexture)),
                    .init(binding: 0, shaderStages: .fragment, resource: .sampler((pbrMaterial?.occlusionTexture ?? Texture2D.whiteTexture).sampler)),
                    .init(binding: Skinning3DUniforms.binding, shaderStages: .vertex, resource: .uniformBuffer(palette, offset: 0)),
                    .init(binding: 4, shaderStages: .fragment, resource: .texture(baseColorTexture)),
                    .init(binding: 5, shaderStages: .fragment, resource: .texture(metallicRoughnessTexture)),
                    .init(binding: 6, shaderStages: .fragment, resource: .texture(normalTexture)),
                    .init(binding: 7, shaderStages: .fragment, resource: .sampler(baseColorTexture.sampler)),
                    .init(binding: 8, shaderStages: .fragment, resource: .sampler(metallicRoughnessTexture.sampler)),
                    .init(binding: 9, shaderStages: .fragment, resource: .sampler(normalTexture.sampler)),
                    .init(binding: 12, shaderStages: .fragment, resource: .texture(emissiveTexture)),
                    .init(binding: 13, shaderStages: .fragment, resource: .sampler(emissiveTexture.sampler)),
                    .init(binding: 17, shaderStages: .fragment, resource: .texture(heightTexture)),
                ] + layerBindings
            ),
            index: 0
        )
        renderEncoder.setVertexBuffer(part.vertexBuffer, offset: 0, slot: 0)
        renderEncoder.setVertexBuffer(
            instances,
            offset: Int(batchRange.lowerBound) * MemoryLayout<Flat3DInstanceData>.stride,
            slot: 3
        )
        renderEncoder.setVertexBuffer(defaultVertexData, offset: 0, slot: 4)
        renderEncoder.setIndexBuffer(part.indexBuffer, offset: 0)
        if !isMotion, let offset = item.indirectArgumentOffset, let arguments = active?.indirectArguments,
           renderEncoder.drawIndexedIndirect(arguments: arguments, offset: offset) { return }
        renderEncoder.drawIndexed(
            indexCount: part.indexCount,
            indexBufferOffset: 0,
            instanceCount: Int(batchRange.count)
        )
    }
}
