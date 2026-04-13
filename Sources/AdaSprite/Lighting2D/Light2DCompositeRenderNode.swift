//
//  Light2DCompositeRenderNode.swift
//  AdaEngine
//

import AdaCorePipelines
import AdaECS
import AdaRender
import AdaUtils
import Math

/// Scratch GPU buffers for 2D lighting (render world).
public struct Lighting2DGPUScratch: Resource, Sendable {
    public var pointUBO: BufferData<PointLightUBOGPU>
    public var directionalUBO: BufferData<DirectionalLightUBOGPU>
    public var compositeModulate: BufferData<Vector4>
    public var shadowVerts: BufferData<QuadVertexData>

    public init() {
        self.pointUBO = BufferData(label: "Light2DPointUBO", elements: [])
        self.directionalUBO = BufferData(label: "Light2DDirUBO", elements: [])
        self.compositeModulate = BufferData(label: "Light2DCompositeModulate", elements: [Vector4(1, 1, 1, 1)])
        self.shadowVerts = BufferData(label: "Light2DShadowVerts", elements: [])
    }
}

/// Composites ``RenderViewTarget/sceneColorTexture`` + lights into ``mainTexture``.
public struct Light2DCompositeRenderNode: RenderNode {

    @Query<
        Entity,
        Camera,
        RenderViewTarget,
        GlobalViewUniform
    >
    private var query

    @Res<ExtractedLighting2D>
    private var extracted

    @Res<Light2DRenderPipelines>
    private var pipelines

    @ResMut<Lighting2DGPUScratch>
    private var scratch

    @Res<RenderDeviceHandler>
    private var renderDeviceHandler

    public init() {}

    public func update(from world: World) {
        query.update(from: world)
        _extracted.update(from: world)
        _pipelines.update(from: world)
        _scratch.update(from: world)
        _renderDeviceHandler.update(from: world)
    }

    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }
        guard extracted.requiresDeferredPipeline else {
            return []
        }
        let device = renderDeviceHandler.renderDevice

        query.forEach { entity, camera, target, uniform in
            if entity != view {
                return
            }
            guard
                let sceneColor = target.sceneColorTexture,
                let lightAccum = target.lightAccumTexture,
                let shadowMask = target.shadowMaskTexture,
                let mainTexture = target.mainTexture
            else {
                return
            }

            let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .surfaceClearColor
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
            commandBuffer.label = "Light2D Composite"

            // Clear light accumulation.
            let clearLightPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Light2D Clear Accum",
                    colorAttachments: [
                        .init(
                            texture: lightAccum,
                            operation: OperationDescriptor(loadAction: .clear, storeAction: .store),
                            clearColor: .black
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )
            clearLightPass.setViewport(camera.viewport.rect)
            clearLightPass.endRenderPass()

            let invVP = uniform.viewProjectionMatrix.inverse
            let white = Texture2D.whiteTexture

            for (lightIndex, light) in extracted.lights.enumerated() {
                let useShadow = light.castsShadows && !extracted.occluders.isEmpty

                if useShadow {
                    let shadowPass = commandBuffer.beginRenderPass(
                        RenderPassDescriptor(
                            label: "Light2D Shadow Mask",
                            colorAttachments: [
                                .init(
                                    texture: shadowMask,
                                    operation: OperationDescriptor(loadAction: .clear, storeAction: .store),
                                    clearColor: .white
                                )
                            ],
                            depthStencilAttachment: nil
                        )
                    )
                    shadowPass.setViewport(camera.viewport.rect)

                    scratch.shadowVerts.elements.removeAll(keepingCapacity: true)
                    for occ in extracted.occluders where occ.isEnabled {
                        let fins: [Vector2]
                        switch light.kind {
                        case .point:
                            fins = Lighting2DShadowMath.shadowFinQuads(
                                lightWorld: light.worldPosition,
                                polygonWorldCCW: occ.worldPointsCCW
                            )
                        case .directional:
                            fins = Lighting2DShadowMath.directionalShadowFinQuads(
                                polygonWorldCCW: occ.worldPointsCCW,
                                lightDirection: light.direction
                            )
                        }
                        var triangleIndex = 0
                        while triangleIndex + 2 < fins.count {
                            let a = fins[triangleIndex]
                            let b = fins[triangleIndex + 1]
                            let c = fins[triangleIndex + 2]
                            for corner in [a, b, c] {
                                scratch.shadowVerts.elements.append(
                                    QuadVertexData(
                                        position: Vector4(corner.x, corner.y, 0, 1),
                                        color: .black,
                                        textureCoordinate: .zero,
                                        textureIndex: 0
                                    )
                                )
                            }
                            triangleIndex += 3
                        }
                    }

                    if !scratch.shadowVerts.elements.isEmpty {
                        scratch.shadowVerts.write(to: device)
                        let whiteSet = RenderResourceSet(
                            bindings: [
                                RenderResourceSet.Binding(
                                    binding: 0,
                                    shaderStages: .fragment,
                                    resource: .texture(white)
                                ),
                                RenderResourceSet.Binding(
                                    binding: 1,
                                    shaderStages: .fragment,
                                    resource: .sampler(white.sampler)
                                ),
                            ]
                        )
                        shadowPass.setResourceSet(whiteSet, index: 0)
                        shadowPass.setVertexBuffer(uniform, slot: GlobalBufferIndex.viewUniform)
                        shadowPass.setVertexBuffer(scratch.shadowVerts, offset: 0, slot: 0)
                        shadowPass.setRenderPipelineState(pipelines.shadowFinPipeline)
                        let count = scratch.shadowVerts.elements.count
                        shadowPass.draw(type: .triangle, vertexStart: 0, vertexCount: count, instanceCount: 1)
                    }
                    shadowPass.endRenderPass()
                }

                let lightPass = commandBuffer.beginRenderPass(
                    RenderPassDescriptor(
                        label: "Light2D Accum \(lightIndex)",
                        colorAttachments: [
                            .init(
                                texture: lightAccum,
                                operation: OperationDescriptor(loadAction: .load, storeAction: .store),
                                clearColor: nil
                            )
                        ],
                        depthStencilAttachment: nil
                    )
                )
                lightPass.setViewport(camera.viewport.rect)

                switch light.kind {
                case .point:
                    let cookie = light.texture ?? white
                    let hasCookie = light.texture != nil
                    let ubo = PointLightUBOGPU(
                        invViewProjection: invVP,
                        lightXYRadius: Vector4(light.worldPosition.x, light.worldPosition.y, light.radius, 0),
                        lightRGBEnergy: Vector4(light.color.red, light.color.green, light.color.blue, light.energy),
                        flags: Vector4(useShadow ? 1 : 0, hasCookie ? 1 : 0, 0, 0)
                    )
                    scratch.pointUBO.elements = [ubo]
                    scratch.pointUBO.write(to: device)

                    let shadowBindings: [RenderResourceSet.Binding] = [
                        RenderResourceSet.Binding(
                            binding: 0,
                            shaderStages: .fragment,
                            resource: .texture(useShadow ? shadowMask : white)
                        ),
                        RenderResourceSet.Binding(
                            binding: 1,
                            shaderStages: .fragment,
                            resource: .sampler(pipelines.sampler)
                        ),
                        RenderResourceSet.Binding(
                            binding: 2,
                            shaderStages: .fragment,
                            resource: .texture(cookie)
                        ),
                        RenderResourceSet.Binding(
                            binding: 3,
                            shaderStages: .fragment,
                            resource: .sampler(cookie.sampler)
                        ),
                    ]
                    let resourceSet = RenderResourceSet(bindings: shadowBindings)
                    lightPass.setResourceSet(resourceSet, index: 0)
                    lightPass.setFragmentBuffer(scratch.pointUBO, offset: 0, slot: 4)
                    lightPass.setRenderPipelineState(pipelines.pointLightPipeline)
                    lightPass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)

                case .directional:
                    let dirUbo = DirectionalLightUBOGPU(
                        lightRGBEnergy: Vector4(light.color.red, light.color.green, light.color.blue, light.energy),
                        flags: Vector4(useShadow ? 1 : 0, 0, 0, 0)
                    )
                    scratch.directionalUBO.elements = [dirUbo]
                    scratch.directionalUBO.write(to: device)

                    let set = RenderResourceSet(
                        bindings: [
                            RenderResourceSet.Binding(
                                binding: 0,
                                shaderStages: .fragment,
                                resource: .texture(useShadow ? shadowMask : white)
                            ),
                            RenderResourceSet.Binding(
                                binding: 1,
                                shaderStages: .fragment,
                                resource: .sampler(pipelines.sampler)
                            ),
                        ]
                    )
                    lightPass.setResourceSet(set, index: 0)
                    lightPass.setFragmentBuffer(scratch.directionalUBO, offset: 0, slot: 2)
                    lightPass.setRenderPipelineState(pipelines.directionalLightPipeline)
                    lightPass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
                }

                lightPass.endRenderPass()
            }

            let mod = extracted.modulate
            scratch.compositeModulate.elements = [
                Vector4(mod.red, mod.green, mod.blue, mod.alpha),
            ]
            scratch.compositeModulate.write(to: device)

            let compositePass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Light2D Composite",
                    colorAttachments: [
                        .init(
                            texture: mainTexture,
                            operation: OperationDescriptor(loadAction: .clear, storeAction: .store),
                            clearColor: clearColor
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )
            compositePass.setViewport(camera.viewport.rect)
            let compositeSet = RenderResourceSet(
                bindings: [
                    RenderResourceSet.Binding(
                        binding: 0,
                        shaderStages: .fragment,
                        resource: .texture(sceneColor)
                    ),
                    RenderResourceSet.Binding(
                        binding: 1,
                        shaderStages: .fragment,
                        resource: .texture(lightAccum)
                    ),
                    RenderResourceSet.Binding(
                        binding: 2,
                        shaderStages: .fragment,
                        resource: .sampler(pipelines.sampler)
                    ),
                ]
            )
            compositePass.setResourceSet(compositeSet, index: 0)
            compositePass.setFragmentBuffer(scratch.compositeModulate, offset: 0, slot: 3)
            compositePass.setRenderPipelineState(pipelines.compositePipeline)
            compositePass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            compositePass.endRenderPass()

            commandBuffer.commit()
        }

        return []
    }
}
