import AdaEngine
import AdaScriptCompilerCore
import Foundation

struct EditorAdaScriptProjectBuildReport: Equatable, Sendable {
    let entryView: String
    let moduleName: String
    let sourceCount: Int
    let systemCount: Int
    let viewCount: Int
}

struct EditorAdaScriptProjectBuildArtifact: Sendable {
    let assetsDirectory: URL
    let entryView: String
    let moduleName: String
    let report: EditorAdaScriptProjectBuildReport
    let sources: [AdaScriptSource]
}

enum EditorAdaScriptProjectBuildError: Error, Equatable, LocalizedError, Sendable {
    case entryViewMissing(identifier: String)
    case nativeDataRequiresRuntimeLayout(names: [String])
    case noSources(path: String)
    case notAdaScriptProject(buildSystem: String)
    case sourceReadFailed(path: String, message: String)

    var errorDescription: String? {
        switch self {
        case .entryViewMissing(let identifier):
            "AdaScript entry view '\(identifier)' was not found. Set runtime.entryView to an existing @view id."
        case .nativeDataRequiresRuntimeLayout(let names):
            "AdaScript runtime components and resources are not available yet: \(names.joined(separator: ", "))."
        case .noSources(let path):
            "No .ada source files were found under \(path)."
        case let .notAdaScriptProject(buildSystem):
            "Expected an AdaScript project, but build.system is '\(buildSystem)'."
        case let .sourceReadFailed(path, message):
            "Failed to read \(path): \(message)"
        }
    }
}

/// Builds a portable AdaScript project directly in the editor process without invoking SwiftPM.
@MainActor
struct EditorAdaScriptProjectBuilder {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func build(project: AdaProject, at projectURL: URL) throws -> EditorAdaScriptProjectBuildReport {
        try prepare(project: project, at: projectURL).report
    }

    func prepare(project: AdaProject, at projectURL: URL) throws -> EditorAdaScriptProjectBuildArtifact {
        guard project.build.system.isAdaScript else {
            throw EditorAdaScriptProjectBuildError.notAdaScriptProject(buildSystem: project.build.system.rawValue)
        }

        let sourceRoot = project.paths.sources ?? "Sources"
        let sources = try loadSources(at: projectURL.appendingPathComponent(sourceRoot, isDirectory: true))
        guard !sources.isEmpty else {
            throw EditorAdaScriptProjectBuildError.noSources(path: sourceRoot)
        }

        let dataSchemas = try AdaScriptSchemaParser.parse(sources: sources)
        guard dataSchemas.isEmpty else {
            throw EditorAdaScriptProjectBuildError.nativeDataRequiresRuntimeLayout(
                names: dataSchemas.map(\.name).sorted()
            )
        }

        let views = try AdaScriptViewScanner.declarations(in: sources)
        let entryView = project.runtime.entryView ?? ""
        guard views.contains(where: { $0.identifier == entryView }) else {
            throw EditorAdaScriptProjectBuildError.entryViewMissing(identifier: entryView)
        }

        let systems = try AdaScriptSchemaParser.parseSystemCapabilities(sources: sources)
        if !systems.isEmpty {
            _ = try AdaScriptPlugin(sources: sources, name: project.runtime.moduleName)
        }
        _ = try AdaScriptView(sources: sources, identifier: entryView)

        let report = EditorAdaScriptProjectBuildReport(
            entryView: entryView,
            moduleName: project.runtime.moduleName,
            sourceCount: sources.count,
            systemCount: systems.count,
            viewCount: views.count
        )
        let assetsPath = project.paths.assets ?? "Assets"
        return EditorAdaScriptProjectBuildArtifact(
            assetsDirectory: projectURL.appendingPathComponent(assetsPath, isDirectory: true),
            entryView: entryView,
            moduleName: project.runtime.moduleName,
            report: report,
            sources: sources
        )
    }

    private func loadSources(at sourceRoot: URL) throws -> [AdaScriptSource] {
        guard let enumerator = fileManager.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sources: [AdaScriptSource] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "ada" {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                continue
            }
            let relativePath = relativePath(from: sourceRoot, to: fileURL)
            do {
                sources.append(
                    AdaScriptSource(
                        path: relativePath,
                        source: try String(contentsOf: fileURL, encoding: .utf8)
                    )
                )
            } catch {
                throw EditorAdaScriptProjectBuildError.sourceReadFailed(
                    path: relativePath,
                    message: error.localizedDescription
                )
            }
        }
        return sources.sorted { $0.path < $1.path }
    }

    private func relativePath(from root: URL, to file: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else {
            return file.lastPathComponent
        }
        return String(filePath.dropFirst(rootPath.count + 1))
    }
}
