//
//  WebGPUBuildPlugin.swift
//  AdaEngine
//
//  Created by build plugin
//

import Foundation
import PackagePlugin

@main
struct WebGPUBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        #if os(Windows)
        return try createWindowsCommands(context: context, target: target)
        #else
        return []
        #endif
    }
    
    #if os(Windows)
    private func createWindowsCommands(context: PluginContext, target: Target) throws -> [Command] {
        let buildDirectory = context.pluginWorkDirectory
        let dllNames = ["vulkan-1.dll", "D3DCompiler.dll"]
        var searchPaths: [String] = [
            "C:\\Windows\\System32",
            "C:\\Windows\\SysWOW64"
        ]
        
        // Добавляем пути из переменных окружения
        if let vulkanSDK = ProcessInfo.processInfo.environment["VULKAN_SDK"], !vulkanSDK.isEmpty {
            searchPaths.append(vulkanSDK)
            searchPaths.append("\(vulkanSDK)\\Bin")
        }
        if let vkSDKPath = ProcessInfo.processInfo.environment["VK_SDK_PATH"], !vkSDKPath.isEmpty {
            searchPaths.append(vkSDKPath)
            searchPaths.append("\(vkSDKPath)\\Bin")
        }
        
        var commands: [Command] = []
        
        for dllName in dllNames {
            let outputPath = buildDirectory.appending(dllName)
            
            let searchPathsString = searchPaths.map { "\"\($0.replacingOccurrences(of: "\\", with: "\\\\"))\"" }.joined(separator: ", ")
            let outputPathEscaped = outputPath.string.replacingOccurrences(of: "\\", with: "\\\\")
            let scriptContent = """
            $dllName = "\(dllName)"
            $outputPath = "\(outputPathEscaped)"
            $searchPaths = @(\(searchPathsString))
            
            $found = $false
            foreach ($path in $searchPaths) {
                if (Test-Path $path) {
                    $dllPath = Join-Path $path $dllName
                    if (Test-Path $dllPath) {
                        $outputDir = Split-Path -Parent $outputPath
                        if (-not (Test-Path $outputDir)) {
                            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                        }
                        Copy-Item $dllPath $outputPath -Force
                        Write-Host "Copied $dllName from $dllPath to $outputPath"
                        $found = $true
                        break
                    }
                }
            }
            
            if (-not $found) {
                Write-Warning "Could not find $dllName in any of the search paths"
            }
            """
            commands.append(
                .prebuildCommand(
                    displayName: "Copy \(dllName) to build directory",
                    executable: Path("C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"),
                    arguments: [
                        "-ExecutionPolicy", "Bypass",
                        "-NoProfile",
                        "-Command", scriptContent
                    ],
                    outputFilesDirectory: buildDirectory
                )
            )
        }
        
        return commands
    }
    #endif
}

