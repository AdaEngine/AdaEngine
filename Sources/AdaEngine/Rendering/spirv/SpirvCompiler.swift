//
//  SpirvCompiler.swift
//  
//
//  Created by v.prusakov on 3/10/23.
//

import SPIRVCompiler

public final class SpirvCompiler {
    
    enum CompileError: LocalizedError {
        case fileReadingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileReadingFailed(let path):
                return "[SpirvCompiler] Failed to read file at path \(path)."
            }
        }
    }
    
    let includeSearchPaths: [String]
    
    public init(includeSearchPaths: [String]) {
        self.includeSearchPaths = includeSearchPaths
    }
    
    public func compileShader(at fileURL: URL) throws {
        guard let data = FileSystem.current.readFile(at: fileURL) else {
            throw CompileError.fileReadingFailed(fileURL.path)
        }
        
        let sourceCode = String(data: data, encoding: .utf8) ?? ""
        self.compileCode(sourceCode)
    }
    
    public func compileCode(_ code: String) {
        guard glslang_init_process() else {
            fatalError("Can't init glslang process")
        }
        
        defer {
            glslang_deinit_process()
        }
        
        var spirvBin: spirv_bin = spirv_bin()
        let error: UnsafeMutablePointer<UnsafePointer<CChar>?> = .allocate(capacity: 1)
        
        let result = code.withCString { ptr in
            return compile_shader_glsl(ptr, SHADER_STAGE_VERTEX, &spirvBin, error)
        }
        
        if let errorMsg = error.pointee {
            fatalError(String(cString: errorMsg, encoding: .utf8)!)
        }
        
        defer {
            error.deallocate()
        }
        
        print(result == SHADERC_FAILURE)
        
        guard result == SHADERC_SUCCESS else {
            return
        }
        
        let data = Data(bytes: spirvBin.bytes, count: Int(spirvBin.length))
        let saveUrl = FileSystem.current.applicationFolderURL.appendingPathComponent("Resources")
            .appendingPathComponent("my_spirv")
            .appendingPathExtension("spv")
        
        print("spv data:\n", data.count, data)
        
        if FileSystem.current.createFile(at: saveUrl, contents: data) {
            print("saved at path \(saveUrl)")
        } else {
            print("not saved")
        }
    }
}
