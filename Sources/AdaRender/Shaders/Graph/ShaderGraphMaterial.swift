import AdaAssets
import Foundation
import Logging

/// Authored reference plus independent parameter overrides. Inline graphs support procedural materials.
public struct ShaderGraphMaterialSource: Codable, Hashable, Sendable {
    public var path: String?
    public var graph: ShaderGraph?
    public var values: [String: [Float]]
    public var textures: [String: String]

    public init(path: String? = nil, graph: ShaderGraph? = nil, values: [String: [Float]] = [:], textures: [String: String] = [:]) {
        self.path = path
        self.graph = graph
        self.values = values
        self.textures = textures
    }

    private enum CodingKeys: CodingKey { case path, graph, values, textures }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        graph = try container.decodeIfPresent(ShaderGraph.self, forKey: .graph)
        values = try container.decodeIfPresent([String: [Float]].self, forKey: .values) ?? [:]
        textures = try container.decodeIfPresent([String: String].self, forKey: .textures) ?? [:]
    }
}

/// Immutable shader code with independently editable, synchronized instance values.
/// `lock` protects authored state and per-device immutable binding snapshots. GPU buffers
/// are replaced rather than overwritten, preserving values used by in-flight commands.
public final class ShaderGraphMaterial: Codable, @unchecked Sendable {
    public let program: ShaderGraphProgram
    let pipelineStorage = ShaderGraphPipelineStorage()
    private let lock = NSLock()
    private var source: ShaderGraphMaterialSource
    private var loadedTextures: [Int: Texture2D] = [:]
    private var revision: UInt64 = 0
    private var time: Float = 0
    private var issue: String?
    private var bindings: [ObjectIdentifier: (device: RenderDevice, revision: UInt64, resources: RenderResourceSet)] = [:]

    public var descriptor: ShaderGraphMaterialSource {
        lock.lock()
        defer { lock.unlock() }
        return source
    }

    public var compilationError: String? {
        lock.lock()
        defer { lock.unlock() }
        return issue
    }

    public func reportCompilationError(_ error: any Error) {
        let message = String(describing: error)
        lock.lock()
        let changed = issue != message
        issue = message
        lock.unlock()
        if changed { Logger(label: "org.adaengine.shader-graph").error("\(message)") }
    }

    public init(source: ShaderGraphMaterialSource) throws {
        let graph: ShaderGraph
        if let inline = source.graph, source.path == nil {
            graph = inline
        } else if let path = source.path, source.graph == nil {
            #if WASM
                throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: path)
            #else
                graph = try AssetsManager.loadSync(ShaderGraphAsset.self, at: path).asset.graph
            #endif
        } else {
            throw ShaderGraphDiagnostic(code: .invalidReference)
        }
        program = try graph.compileGLSL()
        self.source = source
        for (id, value) in source.values { try validate(value, for: id) }
        for id in source.textures.keys where !program.textures.contains(where: { $0.parameterID == id }) {
            throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: id)
        }
        for texture in program.textures {
            let path = texture.parameterID.flatMap { source.textures[$0] } ?? texture.path
            if let path { loadedTextures[texture.binding] = try Self.loadTexture(path, relativeTo: source.path) }
        }
    }

    public convenience init(from decoder: any Decoder) throws {
        try self.init(source: ShaderGraphMaterialSource(from: decoder))
    }

    public func encode(to encoder: any Encoder) throws {
        try descriptor.encode(to: encoder)
    }

    public func value(for id: String) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        return source.values[id] ?? program.parameters.first { $0.id == id }?.defaultValue
    }

    /// Updates numeric uniforms without changing the shader/pipeline identity.
    public func setValue(_ value: [Float], for id: String) throws {
        try validate(value, for: id)
        lock.lock()
        defer { lock.unlock() }
        if source.values[id] != value { source.values[id] = value; revision &+= 1 }
    }

    public func setTexturePath(_ path: String, for id: String) throws {
        guard let texture = program.textures.first(where: { $0.parameterID == id }) else {
            throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: id)
        }
        let loaded = try Self.loadTexture(path, relativeTo: descriptor.path)
        lock.lock()
        defer { lock.unlock() }
        source.textures[id] = path
        loadedTextures[texture.binding] = loaded
        revision &+= 1
    }

    public func setTime(_ seconds: Float) {
        guard seconds.isFinite else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        if time != seconds { time = seconds; revision &+= 1 }
    }

    /// Called on the renderer's owning context. A revision reuses one immutable snapshot per device.
    public func resourceSet(device: RenderDevice) -> RenderResourceSet {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(device)
        if let cached = bindings[key], cached.revision == revision {
            return cached.resources
        }
        var words = [Float](repeating: 0, count: (program.parameters.count + 1) * 4)
        words[0] = time
        for parameter in program.parameters {
            let value = source.values[parameter.id] ?? parameter.defaultValue
            for (index, number) in value.enumerated() { words[parameter.slot * 4 + index] = number }
        }
        let buffer = device.createUniformBuffer(length: words.count * MemoryLayout<Float>.stride, binding: ShaderGraphProgram.uniformBinding)
        buffer.setElements(&words)
        var resources: [RenderResourceSet.Binding] = [
            .init(binding: ShaderGraphProgram.uniformBinding, shaderStages: .fragment, resource: .uniformBuffer(buffer, offset: 0))
        ]
        for texture in program.textures {
            resources.append(.init(binding: texture.binding, shaderStages: .fragment, resource: .texture(loadedTextures[texture.binding] ?? .whiteTexture)))
        }
        if let first = program.textures.first {
            let texture = loadedTextures[first.binding] ?? .whiteTexture
            resources.append(.init(binding: ShaderGraphProgram.samplerBinding, shaderStages: .fragment, resource: .sampler(texture.sampler)))
        }
        let result = RenderResourceSet(bindings: resources)
        bindings[key] = (device, revision, result)
        return result
    }

    private func validate(_ value: [Float], for id: String) throws {
        guard let parameter = program.parameters.first(where: { $0.id == id }) else {
            throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: id)
        }
        guard value.count == parameter.type.componentCount, value.allSatisfy(\.isFinite),
            parameter.type != .bool || value == [0] || value == [1] else {
            throw ShaderGraphDiagnostic(code: .invalidLiteral, nodeID: id)
        }
    }

    private static func loadTexture(_ path: String, relativeTo graph: String?) throws -> Texture2D {
        #if WASM
            throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: path)
        #else
            let resolved: String
            if !path.hasPrefix("@"), !path.hasPrefix("/"), let graph, let slash = graph.lastIndex(of: "/") {
                resolved = String(graph[...slash]) + path
            } else { resolved = path }
            return try AssetsManager.loadSync(Texture2D.self, at: resolved).asset
        #endif
    }
}
