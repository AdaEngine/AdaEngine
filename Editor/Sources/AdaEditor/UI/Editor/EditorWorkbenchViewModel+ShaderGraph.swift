import Foundation

extension EditorWorkbenchViewModel {
    func shaderGraphModel(for document: EditorAssetDocument) -> EditorShaderGraphModel {
        if let model = shaderGraphModels[document.id] {
            return model
        }
        let model = EditorShaderGraphModel(url: document.absolutePath.map { URL(fileURLWithPath: $0) })
        model.onChange = { [weak self, weak model] _ in
            guard let self, let model, let index = self.openDocuments.firstIndex(where: { $0.id == document.id }), case .asset(var current) = self.openDocuments[index] else {
                return
            }
            current.isDirty = model.isDirty
            current.errorMessage = model.diagnosticMessage
            self.openDocuments[index] = .asset(current)
            self.onDocumentEdited?(document.id)
        }
        shaderGraphModels[document.id] = model
        return model
    }
}
