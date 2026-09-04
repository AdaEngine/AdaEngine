@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorAdaScriptPreviewArtifact: Sendable {
    var identifier: String
    var sources: [AdaScriptSource]
}

actor EditorAdaScriptPreviewBuilder {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func build(_ request: EditorPreviewBuildRequest) throws -> EditorAdaScriptPreviewArtifact {
        guard request.declaration.kind == .adaScript else {
            throw EditorPreviewBuildFailure(message: "Expected an Ada Script preview declaration.")
        }
        guard let target = request.packageModel.target(containing: request.document, projectURL: request.projectURL) else {
            throw EditorPreviewBuildFailure(message: "Could not resolve the SwiftPM target for \(request.document.relativePath).")
        }

        let sourceRoot = URL(
            fileURLWithPath: target.path ?? "Sources/\(target.name)",
            relativeTo: request.projectURL
        ).standardizedFileURL
        guard let enumerator = fileManager.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw EditorPreviewBuildFailure(message: "Could not enumerate Ada Script sources in \(target.name).")
        }

        let activeURL = request.document.absolutePath.map {
            URL(fileURLWithPath: $0, isDirectory: false).standardizedFileURL
        }
        var sources: [AdaScriptSource] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "ada" {
            let standardizedURL = url.standardizedFileURL
            let source: String
            if standardizedURL == activeURL {
                source = request.document.content
            } else {
                source = try String(contentsOf: standardizedURL, encoding: .utf8)
            }
            sources.append(
                AdaScriptSource(
                    path: relativePath(from: sourceRoot, to: standardizedURL),
                    source: source
                )
            )
        }
        sources.sort { $0.path < $1.path }
        guard !sources.isEmpty else {
            throw EditorPreviewBuildFailure(message: "Target \(target.name) contains no .ada sources.")
        }
        return EditorAdaScriptPreviewArtifact(identifier: request.declaration.id, sources: sources)
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
