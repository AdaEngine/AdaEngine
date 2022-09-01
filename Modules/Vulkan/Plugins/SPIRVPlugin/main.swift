//
//  main.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

import PackagePlugin
import Foundation

@main
class SPIRVPlugin: CommandPlugin {
    
    required init() {}
    
    let fileManager = FileManager.default
    
    private var isVerboseMode: Bool = false
    
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        
        if arguments.isEmpty {
            self.showHelp()
            return
        }
        
        if arguments.contains("--help") || arguments.contains("-h") {
            self.showHelp()
            return
        }
        
        // Argument parser
        var exctractor = ArgumentExtractor(arguments)
        
        // We should verbose our actions if user passed verbose flag
        isVerboseMode = exctractor.extractFlag(named: "verbose") == 1
        
        verbose("Exctract VULKAN_SDK from environment.")
        
        let vulkanPath = ProcessInfo.processInfo.environment["VULKAN_SDK"] ?? ""

        verbose("Check that glsl compiler exists at path \'\(vulkanPath)/bin/glslc\'")
        let executableURL = URL(fileURLWithPath: "\(vulkanPath)/bin/glslc")
        
        guard self.fileManager.fileExists(atPath: executableURL.path) else {
            Diagnostics.error(SPIRVError.glslCompilerNotFound.localizedDescription)
            return
        }
        
        verbose("Extract passed arguments:\n\(arguments.joined(separator: "\n"))")
        
        var files: [Path] = []
        
        if arguments.contains("--input-folder") {
            verbose("User passed --input-folder, trying to find glsl files.")
            
            guard let dir = exctractor.extractOption(named: "input-folder").first.flatMap({ Path($0) }) else {
                Diagnostics.error(SPIRVError.noInputFolder.localizedDescription)
                return
            }
            
            files = try self.findGLSLFiles(for: dir)
        } else {
            verbose("User passed --input-files.")
            files = exctractor.extractOption(named: "input-files").map { Path($0) }
        }
        
        if files.isEmpty {
            Diagnostics.error(SPIRVError.noInputFiles.localizedDescription)
            return
        }
        
        guard let outputPath = exctractor.extractOption(named: "output").first.flatMap(Path.init) else {
            Diagnostics.error(SPIRVError.outputPathNotPassed.localizedDescription)
            return
        }
        
        verbose("We found next files:\n\(files.map { $0.string }.joined(separator: "\n"))")
        
        for file in files {
            var filePath = file.lastComponent
            
            if file.extension == "glsl" {
                filePath.removeLast(5) // -> .glsl
            }
            
            let output = outputPath.appending("\(filePath).spv")
            
            verbose("Compile \(file.string) in \(output.string)")
            
            try Process.run(executableURL, arguments: [
                file.string,
                "-o",
                output.string
            ])
        }
    }
    
    // MARK: - Private
    
    private func findGLSLFiles(for dir: Path) throws -> [Path] {
        var isDir: ObjCBool = false
        guard self.fileManager.fileExists(atPath: dir.string, isDirectory: &isDir), isDir.boolValue == true else {
            Diagnostics.error(SPIRVError.directoryNotExistsAt(dir).localizedDescription)
            return []
        }
        
        let lookedExtentsions = ["glsl", "frag", "vert"]
        
        let paths: [Path] = try self.fileManager.contentsOfDirectory(atPath: dir.string)
            .map { Path($0) }
            .filter { lookedExtentsions.contains($0.extension ?? "") }
            .map {
                dir.appending($0.string)
            }
        
        return paths
    }
    
    private func showHelp() {
        print(PluginHelp.helpOverview)
    }
    
    private func verbose(_ log: String) {
        guard isVerboseMode else { return }
        print(log, "\n")
    }
}

enum SPIRVError: LocalizedError {
    case glslCompilerNotFound
    case outputPathNotPassed
    case noInputFiles
    case noInputFolder
    case directoryNotExistsAt(Path)
    
    var errorDescription: String? {
        switch self {
        case .glslCompilerNotFound:
            return "GLSL Compiler not found at path"
        case .outputPathNotPassed:
            return "Required option `--ouput` not passed."
        case .noInputFolder:
            return "Not passed path for folder."
        case .noInputFiles:
            return "Input files not found. Use option `--input-folder` or `--input-files`."
        case .directoryNotExistsAt(let path):
            return "Could not find a directory at path: \(path.string)"
        }
    }
}
