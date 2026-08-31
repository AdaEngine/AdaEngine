import Foundation
import PackagePlugin

@main
struct AdaScriptBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceModule = target.sourceModule else {
            return []
        }

        let tool = try context.tool(named: "AdaScriptGeneratorTool")
        let scripts = sourceModule.sourceFiles
            .map(\.url)
            .filter { $0.pathExtension.lowercased() == "ada" }
            .sorted { $0.path < $1.path }
        let output = context.pluginWorkDirectoryURL.appendingPathComponent("AdaScriptPluginsGenerated.swift")

        return [
            .buildCommand(
                displayName: "Generate Ada script plugins for \(target.name)",
                executable: tool.url,
                arguments: [
                    "--output", output.path,
                    "--root", target.directoryURL.path,
                    "--module-name", target.name
                ] + scripts.map(\.path),
                environment: [:],
                inputFiles: scripts,
                outputFiles: [output]
            )
        ]
    }
}
