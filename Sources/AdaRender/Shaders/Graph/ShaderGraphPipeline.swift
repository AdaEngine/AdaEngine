import Foundation

/// GPU creation stays on the caller's render context. Locks guard only bounded cache state.
final class ShaderGraphPipelineStorage: @unchecked Sendable {
    static let shared = ShaderGraphPipelineStorage()
    struct Key: Hashable {
        let device: ObjectIdentifier
        let vertex: ObjectIdentifier
        let layout: VertexDescriptor
        let variant: String
        let defines: [ShaderDefine]
        var source = ""
    }
    private let lock = NSLock()
    private var entries: [Key: (RenderDevice, Result<RenderPipeline, any Error>)] = [:]
    private var order: [Key] = []

    func resolve(_ key: Key, device: RenderDevice, cacheFailure: Bool, create: () throws -> RenderPipeline) throws -> RenderPipeline {
        lock.lock()
        defer { lock.unlock() }
        if let cached = entries[key] {
            return try cached.1.get()
        }
        do {
            let pipeline = try create()
            insert(.success(pipeline), key: key, device: device)
            return pipeline
        } catch {
            if cacheFailure { insert(.failure(error), key: key, device: device) }
            throw error
        }
    }

    private func insert(_ value: Result<RenderPipeline, any Error>, key: Key, device: RenderDevice) {
        if order.count >= 256, let first = order.first { entries.removeValue(forKey: first); order.removeFirst() }
        order.append(key)
        entries[key] = (device, value)
    }
}

extension ShaderGraphMaterial {
    /// Replaces only a fragment stage. `variant` identifies the base pipeline's render state.
    /// A template contains `#define ADA_GRAPH_SOURCE_MARKER 1` before its main function.
    public func pipeline(
        base: RenderPipelineDescriptor,
        device: RenderDevice,
        variant: String,
        defines: [ShaderDefine] = [],
        fragmentTemplate: () throws -> String
    ) throws -> RenderPipeline {
        let key = ShaderGraphPipelineStorage.Key(
            device: ObjectIdentifier(device),
            vertex: ObjectIdentifier(base.vertex),
            layout: base.vertexDescriptor,
            variant: variant,
            defines: defines.sorted { $0.name < $1.name }
        )
        let pipeline = try pipelineStorage.resolve(key, device: device, cacheFailure: true) {
            let template = try fragmentTemplate()
            guard template.contains("#define ADA_GRAPH_SOURCE_MARKER 1") else {
                throw ShaderGraphDiagnostic(code: .invalidReference)
            }
            let generated = program.inserting(in: template)
            var sharedKey = key
            sharedKey.source = generated
            return try ShaderGraphPipelineStorage.shared.resolve(sharedKey, device: device, cacheFailure: false) {
                let source = ShaderSource()
                source.setSource(generated, for: .fragment)
                let compiler = ShaderCompiler(shaderSource: source)
                compiler.setMacro("ADA_SHADER_GRAPH", value: "1", for: .fragment)
                for define in defines { compiler.setMacro(define.name, value: define.value, for: .fragment) }
                var descriptor = base
                if unsafe RenderEngine.shared.type.deviceLang == .wgsl,
                    let artifact = ShaderGraphRuntimeLibrary.fragment(source: generated, defines: defines) {
                    let shader = Shader(source: artifact.wgsl, entryPoint: artifact.entryPoint, stage: .fragment, reflectionData: artifact.reflection)
                    try shader.compile()
                    descriptor.fragment = shader
                } else {
                    #if WASM
                    throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: "Missing baked Shader Graph variant: \(variant)")
                    #else
                    descriptor.fragment = try compiler.compileShader(for: .fragment)
                    #endif
                }
                descriptor.debugName += " Shader Graph"
                return device.createRenderPipeline(from: descriptor)
            }
        }
        recordPipelinePreparation()
        return pipeline
    }
}
