//
//  main.swift
//  
//
//  Created by v.prusakov on 5/25/22.
//

import PackagePlugin

@main
struct SwiftLintPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let lintFilePath = context.package.directory.appending(".swiftlint.yml")
        let swintLint = try context.tool(named: "swiftlint")
        
        return [
            .buildCommand(
                displayName: "Running SwiftLint for \(target.name)",
                executable: swintLint.path,
                arguments: [
                    "lint",
                    "--in-process-sourcekit",
                    "--path",
                    target.directory.string,
                    "--config",
                    lintFilePath.string
                ],
                environment: [:]
            )
        ]
    }
}
