@_spi(AdaEngine) import AdaEngine

extension EditorUISceneEditor {
    func designerDragGesture(_ source: EditorUIDesignerDrag.Source) -> some Gesture {
        DragGesture(minimumDistance: 8, minimumPressDuration: 0.3)
            .onChanged { value in
                model.designerDrag.change(source: source, start: value.startLocation, location: value.location) {
                    if model.designerDrag.isCompact { compactPane = .canvas }
                }
            }
            .onEnded { value in model.designerDrag.end(at: value.location) }
            .onCancelled { model.designerDrag.cancel() }
    }
}
