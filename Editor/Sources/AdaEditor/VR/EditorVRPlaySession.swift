import AdaEngine
import Foundation

/// A portable project runtime owned by a native Play window, separate from authoring.
@MainActor
final class EditorVRPlaySession {
    static let windowID = "vr-project-play"
    let id = UUID()
    let title: String
    let controls: EditorGameWindowControls
    let runtime: EditorAdaScriptProjectRuntimeView

    init(artifact: EditorAdaScriptProjectBuildArtifact, title: String) throws {
        self.title = artifact.window.title.flatMap { $0.isEmpty ? nil : $0 } ?? title
        let size = artifact.window.size
        controls = EditorGameWindowControls(projectSize: Size(width: Float(size.width), height: Float(size.height)))
        runtime = try EditorAdaScriptProjectRuntimeView(artifact: artifact, controls: controls)
    }
}
