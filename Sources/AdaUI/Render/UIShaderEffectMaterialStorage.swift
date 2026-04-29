//
//  UIShaderEffectMaterialStorage.swift
//  AdaEngine
//

import AdaCorePipelines
import AdaRender
import AdaUtils

struct UIShaderEffectMaterialKey: Hashable {
    let defines: [ShaderDefine]
    let vertexDescriptor: VertexDescriptor
}

private final class UIShaderEffectPipelineStorage {
    nonisolated(unsafe) static let shared = UIShaderEffectPipelineStorage()

    private var pipelines: [RID: [UIShaderEffectMaterialKey: RenderPipeline]] = [:]

    private init() {}

    func pipeline(for material: Material, key: UIShaderEffectMaterialKey) -> RenderPipeline? {
        pipelines[material.rid]?[key]
    }

    func setPipeline(_ pipeline: RenderPipeline, for material: Material, key: UIShaderEffectMaterialKey) {
        pipelines[material.rid, default: [:]][key] = pipeline
    }
}

extension Material {
    func getOrCreateUIShaderEffectPipeline(device: RenderDevice) -> RenderPipeline? {
        let vertexDescriptor = VertexDescriptor.uiShaderEffect
        let materialKey = UIShaderEffectMaterialKey(
            defines: self.collectDefines(for: vertexDescriptor, keys: []),
            vertexDescriptor: vertexDescriptor
        )

        if let pipeline = unsafe UIShaderEffectPipelineStorage.shared.pipeline(for: self, key: materialKey) {
            return pipeline
        }

        guard let (pipeline, shaderModule) = self.createUIShaderEffectPipeline(
            for: materialKey,
            device: device
        ) else {
            return nil
        }

        let data = unsafe MaterialStorage.shared.getMaterialData(for: self) ?? MaterialStorageData()
        data.updateUniformBuffers(from: shaderModule)
        unsafe MaterialStorage.shared.setMaterialData(data, for: self)
        unsafe UIShaderEffectPipelineStorage.shared.setPipeline(pipeline, for: self, key: materialKey)
        self.update()
        return pipeline
    }

    private func createUIShaderEffectPipeline(
        for materialKey: UIShaderEffectMaterialKey,
        device: RenderDevice
    ) -> (RenderPipeline, ShaderModule)? {
        let compiler = ShaderCompiler(shaderSource: self.shaderSource)

        for define in materialKey.defines {
            compiler.setMacro(define.name, value: define.value, for: .vertex)
            compiler.setMacro(define.name, value: define.value, for: .fragment)
        }

        do {
            let shaderModule = try compiler.compileShaderModule()
            guard let pipelineDescriptor = self.configureRenderPipeline(
                for: materialKey.vertexDescriptor,
                keys: [],
                shaderModule: shaderModule
            ) else {
                return nil
            }

            return (device.createRenderPipeline(from: pipelineDescriptor), shaderModule)
        } catch {
            assertionFailure("[UIShaderEffect] \(error)")
            return nil
        }
    }
}

private extension VertexDescriptor {
    static var uiShaderEffect: VertexDescriptor {
        var descriptor = VertexDescriptor()
        descriptor.attributes.append([
            .attribute(.vector4, name: "a_Position"),
            .attribute(.vector4, name: "a_Color"),
            .attribute(.vector2, name: "a_TexCoordinate"),
        ])
        descriptor.layouts[0].stride = MemoryLayout<QuadVertexData>.stride
        return descriptor
    }
}
