//
//  main.swift
//  
//
//  Created by v.prusakov on 5/26/22.
//

import Foundation
import PackagePlugin

@main
struct SPIRVBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        //        let targetURL = URL(string: target.directory.string)!
        
//        let spirv = try context.tool(named: "swift")
        //
        //        if target.name != "AdaEngine" {
        //            return []
        //        }
        
//        let shadersPath = target.directory.appending(["Assets", "Shaders", "Vulkan"])
        
        return [
//            .buildCommand(
//                displayName: "SPIRV Build Plugin",
//                executable: spirv.path,
//                arguments: [
//                    "plugin",
//                    "spirv",
//                    "--input-folder",
//                    shadersPath.string,
//                    "--output",
//                    shadersPath.string
//                ],
//                outputFiles: [shadersPath]
//            ),
            
        ]
    }
}
