import AdaEngine

extension EditorInspectorSidebar {
    func spineChoiceField(_ field: EditorInspectorSidebarViewModel.ComponentField) -> some View {
        let source = viewModel.selectedEntity?.components.first { $0.typeName == EditorBuiltInComponentType.spineSource }?
            .fields.first { $0.field.key == "source" }?.value ?? ""
        let path = viewModel.spineAssets.first { $0.reference == source }?.absolutePath
        let isAnimation = field.field.key == "animation"
        let emptyLabel = isAnimation ? "Setup pose" : "Default skin"
        let names = isAnimation ? spineCatalog.skeleton?.animationNames : spineCatalog.skeleton?.skinNames
        let binding = viewModel.componentFieldBinding(typeName: field.typeName, field: field.field)
        return VStack(alignment: .leading, spacing: 4) {
            EditorEnumField(cases: [emptyLabel] + (names ?? []), selection: Binding(
                get: { binding.wrappedValue.isEmpty ? emptyLabel : binding.wrappedValue },
                set: { binding.wrappedValue = $0 == emptyLabel ? "" : $0 }),
                accessibilityID: "AdaEditor.Inspector.Spine.\(field.field.key)")
            if let error = spineCatalog.error, path != nil { Text(error).font(.system(size: 10)).foregroundColor(.red) }
        }
        .onAppear { if let path { spineCatalog.load(path: path) } }
        .onChange(of: path) { _, path in spineCatalog.load(path: path) }
    }
}
