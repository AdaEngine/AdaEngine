import Foundation

extension URL {
    /// Apple document-provider URLs need a security scope; Android's picker
    /// imports private file copies before handing them to the shared editor.
    func startAccessingEditorResource() -> Bool {
        #if canImport(Darwin)
        startAccessingSecurityScopedResource()
        #else
        false
        #endif
    }

    func stopAccessingEditorResource() {
        #if canImport(Darwin)
        stopAccessingSecurityScopedResource()
        #endif
    }
}
