//
//  TextureAtlasBuildPlugin.swift
//  AdaEngine
//

import Foundation
import PackagePlugin

@main
struct TextureAtlasBuildPlugin: BuildToolPlugin {

    private let fileManager = FileManager.default

    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let tool = try context.tool(named: "TextureAtlasBuilderTool")
        let root = URL(fileURLWithPath: target.directory.string, isDirectory: true)

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var configs: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if item.lastPathComponent.hasSuffix(".atlas.json") {
                configs.append(item)
            }
        }
        configs.sort { $0.path < $1.path }

        var commands: [Command] = []

        for configURL in configs {
            let data = try Data(contentsOf: configURL)
            let lite = try JSONDecoder().decode(AtlasConfigLite.self, from: data)
            let baseDir = configURL.deletingLastPathComponent()
            let inputDir = baseDir.appendingPathComponent(lite.inputDirectory, isDirectory: true)

            var inputs: [Path] = [Path(configURL.path)]
            if fileManager.fileExists(atPath: inputDir.path) {
                let pngs = try fileManager.contentsOfDirectory(
                    at: inputDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ).filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.path < $1.path }
                inputs.append(contentsOf: pngs.map { Path($0.path) })
            }

            let safeName = lite.atlasName.replacingOccurrences(of: " ", with: "_")
            let outName = "\(safeName)Atlas+Generated.swift"
            let outPath = context.pluginWorkDirectory.appending(outName)

            commands.append(
                .buildCommand(
                    displayName: "Pack texture atlas \(lite.atlasName)",
                    executable: tool.path,
                    arguments: [
                        "--config", configURL.path,
                        "--output-swift", outPath.string
                    ],
                    environment: [:],
                    inputFiles: inputs,
                    outputFiles: [outPath]
                )
            )
        }

        return commands
    }
}

private struct AtlasConfigLite: Codable, Sendable {
    var atlasName: String
    var inputDirectory: String
}
