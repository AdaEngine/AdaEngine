//
//  Shader.swift
//  
//
//  Created by v.prusakov on 11/4/21.
//

public protocol CompiledShader: AnyObject {
    
}

// TODO: Add hash
// TODO: Add reflection data
public final class Shader: Resource {
    
    public fileprivate(set) var compiledShader: CompiledShader!
    public let stage: ShaderStage
    public private(set) var spirvData: Data
    
    internal private(set) var spirvCompiler: SpirvCompiler
    
    private var shaderCompiler: ShaderCompiler
    
    fileprivate init(spirv: SpirvBinary, compiler: ShaderCompiler) throws {
        self.spirvData = spirv.data
        self.spirvCompiler = try SpirvCompiler(spriv: spirv.data)
        self.stage = spirv.stage
        self.shaderCompiler = compiler
        self.compiledShader = nil
    }
    
    public func reload() throws {
        let spirv = try shaderCompiler.compileSpirvBin(for: self.stage)
        self.spirvData = spirv.data
        self.spirvCompiler = try SpirvCompiler(spriv: spirv.data)
        self.compiledShader = try RenderEngine.shared.compileShader(from: self)
    }
    
    // MARK: Shader

    public var resourceName: String = ""
    public var resourcePath: String = ""
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
        self.spirvCompiler = shader.spirvCompiler
        self.stage = stage
        self.compiledShader = shader.compiledShader
    }

    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError("TODO")
    }
    
    static func make(from spirv: SpirvBinary, compiler: ShaderCompiler) throws -> Shader {
        let shader = try Shader(spirv: spirv, compiler: compiler)
        let compiledShader = try RenderEngine.shared.compileShader(from: shader)
        shader.compiledShader = compiledShader
        return shader
    }

}