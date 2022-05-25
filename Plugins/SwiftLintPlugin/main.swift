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
        return [
            .buildCommand(
                displayName: "Running SwiftLint for \(target.name)",
                executable: try context.tool(named: "swiftlint").path,
                arguments: [
                    "lint",
                    "--in-process-sourcekit",
                    "--path",
                    target.directory.string,
                    "--config",
                    "\(context.package.directory.string)/.swiftlint.yml"
                ],
                environment: [:]
            )
        ]
    }
}
