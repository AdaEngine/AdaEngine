#if canImport(WebGPU)
import WebGPU
import Subprocess
import Foundation
import System

struct WGSLShaderCompiler: ShaderDeviceCompilerEngine {
    func compile(
        spirvData: Data, 
        entryPoint: String, 
        stage: ShaderStage,
        defines: [ShaderDefine]
    ) async throws -> DeviceCompiledShader {
        guard let toolExecutable = Bundle.module.tintExecutable else {
            throw ShaderCompilerError.tintNotFound
        }

        let tempFileURL = try getTempFileURL(from: spirvData)

        let process = try await run(
            .path(System.FilePath(toolExecutable.path())), 
            arguments: [
                tempFileURL.path(),
                "--entry-point",
                entryPoint,
                "--format", 
                "wgsl"
            ],
            output: .string(limit: .max),
            error: .string(limit: 1024)
        )
        try FileManager.default.removeItem(at: tempFileURL)

        if let error = process.standardError {
            throw ShaderCompilerError.failed(error)
        }

        if case let .unhandledException(status) = process.terminationStatus, status != 0 {
            throw ShaderCompilerError.failed("Process terminated with status \(status)")
        }

        guard let source = process.standardOutput else {
            throw ShaderCompilerError.failed("No output")
        }

        return DeviceCompiledShader(
            source: source, 
            language: .wgsl, 
            entryPoints: [
                .init(name: entryPoint, stage: stage)
            ]
        )
    }

    func getTempFileURL(from sprivData: Data) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".spv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        try sprivData.write(to: fileURL)
        return fileURL
    }

    enum ShaderCompilerError: LocalizedError {
        case tintNotFound
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .tintNotFound:
                return "Tint tool not found"
            case .failed(let message):
                return "Failed to compile shader: \(message)"
            }
        }
    }
}

extension Bundle {
    var tintExecutable: URL? {
        #if os(Windows)
        return url(forResource: "tint", withExtension: "exe")
        #else
        return url(forResource: "tint", withExtension: "")
        #endif
    }
}
#endif