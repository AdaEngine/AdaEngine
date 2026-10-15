/// Services the editor implements for extensions.
@MainActor
public protocol EditorHostServices: AnyObject {
    /// Project-relative path of the active document, if any.
    var activeDocumentPath: String? { get }

    /// Runs `body` as one undoable step. A thrown error discards the edits made in `body`.
    func performTransaction(named name: String, _ body: () throws -> Void) throws
}
