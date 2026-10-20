import Foundation

extension EditorShaderGraphModel {
    var diagnosticMessage: String? {
        if let error = issue as? EditorShaderGraphFileError {
            switch error {
            case .changedOnDisk: return L10n.text("The graph changed on disk. Your edits are kept; reload after saving a copy.")
            case .unsavedChanges: return L10n.text("Save your graph edits before reloading.")
            case .readOnly: return L10n.text("This graph is read-only.")
            case .unavailable: return L10n.text("The graph file is unavailable.")
            }
        }
        if let validation {
            return L10n.text("Graph error: \(validation.code.rawValue), node: \(validation.nodeID ?? "—"), port: \(validation.port ?? "—")")
        }
        if issue != nil {
            return L10n.text("Unable to read or save the graph. Check its format and file permissions.")
        }
        return nil
    }
}
