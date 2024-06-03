//
//  Shader.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/4/21.
//

/// Contains native compiled GPU device shader.
public protocol CompiledShader: AnyObject {}

// TODO: (Vlad) Add hash
// TODO: (Vlad) Add reflection data
// TODO: (Vlad) I'm not sure that we should save compiled shader inside `Shader` object.

/// Contains shader data.
public final class Shader: Resource {
    
    /// Return compiled shader which used for specific render backend.
    public fileprivate(set) var compiledShader: CompiledShader!
    
    /// Contains information about shader stage.
    public let stage: ShaderStage
    
    /// Return SPIRV binary.
    public private(set) var spirvData: Data
    
    internal private(set) var spirvCompiler: SpirvCompiler
    
    private var shaderCompiler: ShaderCompiler
    
    var reflectionData: ShaderReflectionData = ShaderReflectionData()
    
    fileprivate init(spirv: SpirvBinary, compiler: ShaderCompiler) throws {
        self.spirvData = spirv.data
        self.spirvCompiler = try SpirvCompiler(spriv: spirv.data, stage: spirv.stage)
        self.spirvCompiler.renameEntryPoint(spirv.entryPoint)
        
        self.stage = spirv.stage
        self.shaderCompiler = compiler
        self.compiledShader = nil
    }
    
    /// Add new macro to the shader. When all macros has been set, use ``recompile()`` method to apply new changes.
    public func setMacro(_ name: String, value: String) {
        self.shaderCompiler.setMacro(name, value: value, for: self.stage)
    }
    
    /// Recompile shader. If you change macros values, than you should recompile shader and apply new changes.
    public func recompile() throws {
        let spirv = try shaderCompiler.compileSpirvBin(for: self.stage)
        self.spirvData = spirv.data
        self.spirvCompiler = try SpirvCompiler(spriv: spirv.data, stage: self.stage)
        self.spirvCompiler.renameEntryPoint(spirv.entryPoint)
        
        self.compiledShader = try RenderEngine.shared.compileShader(from: self)
    }
    
    // MARK: Shader

    public var resourceMetaInfo: ResourceMetaInfo?
    public static var resourceType: ResourceType = .material

    // TODO: Load from spir-v
    public init(asset decoder: AssetDecoder) throws {
        let filePath = decoder.assetMeta.filePath
        let shaderSource = try ShaderSource(from: filePath)
        let stage = ShaderUtils.shaderStage(from: decoder.assetMeta.queryParams.first?.name ?? "") ?? shaderSource.stages.first

        guard let stage else {
            throw AssetDecodingError.decodingProblem("No shader stage found in shader \(filePath)")
        }
        
        self.shaderCompiler = ShaderCompiler(shaderSource: shaderSource)
        let spirv = try self.shaderCompiler.compileSpirvBin(for: stage)
        let shader = try Self.make(from: spirv, compiler: self.shaderCompiler)
        self.spirvData = shader.spirvData
        self.reflectionData = shader.reflectionData
        self.spirvCompiler = shader.spirvCompiler
        self.stage = stage
        self.compiledShader = shader.compiledShader
    }

    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    static func make(from spirv: SpirvBinary, compiler: ShaderCompiler) throws -> Shader {
        let shader = try Shader(spirv: spirv, compiler: compiler)
        let compiledShader = try RenderEngine.shared.compileShader(from: shader)
        shader.compiledShader = compiledShader
        
        return shader
    }
    
    // MARK: - Private
    
    func reflect() -> ShaderReflectionData {
        return self.spirvCompiler.reflection()
    }
}

// MARK: UniqueHashable

extension Shader: UniqueHashable {
    public static func == (lhs: Shader, rhs: Shader) -> Bool {
        lhs.spirvData == rhs.spirvData &&
        lhs.stage == rhs.stage &&
        lhs.resourcePath == rhs.resourcePath
    }
    
    public func hash(into hasher: inout FNVHasher) {
        hasher.combine(self.resourcePath)
    }
}
