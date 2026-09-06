@_spi(AdaEngine) import AdaEngine

extension EditorInspectorSidebar {
    func compactActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.blue)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
        }
        .buttonStyle(DefaultButtonStyle())
    }

    @ViewBuilder
    var addComponentPicker: some View {
        if let selectedEntity = viewModel.selectedEntity, !selectedEntity.addableComponents.isEmpty {
            Button(action: {
                showsComponentPicker.toggle()
                componentSearchText = ""
            }) {
                HStack(spacing: 6) {
                    Text("+").font(.system(size: 15))
                    Text("Add Component").font(.system(size: 11))
                    Spacer()
                    Text(showsComponentPicker ? "\u{E5CE}" : "\u{E5CF}")
                        .font(AdaEditorMaterialSymbolFont.font(size: 16))
                }
                .foregroundColor(theme.editorColors.blue)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.blue.opacity(0.12)))
                .overlay { RoundedRectangleShape(cornerRadius: 6).stroke(theme.editorColors.blue.opacity(0.35), lineWidth: 1) }
            }
            .buttonStyle(DefaultButtonStyle())
            .accessibilityIdentifier("AdaEditor.Inspector.AddComponent")

            if showsComponentPicker {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Search components", text: Binding(get: { componentSearchText }, set: { componentSearchText = $0 }))
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.text)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.background))
                        .textFieldStyle(PlainTextFieldStyle())
                        .accessibilityIdentifier("AdaEditor.Inspector.ComponentSearch")
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(viewModel.addableComponents(matching: componentSearchText), id: \.typeName) { component in
                                addComponentRow(component)
                            }
                        }
                    }
                    .frame(height: 210)
                }
                .padding(7)
                .background(RoundedRectangleShape(cornerRadius: 7).fill(theme.editorColors.surfaceElevated))
                .overlay { RoundedRectangleShape(cornerRadius: 7).stroke(theme.editorColors.border, lineWidth: 1) }
            }
        }
    }

    func addComponentRow(_ component: EditorInspectorSidebarViewModel.AddableComponent) -> some View {
        Button(action: {
            viewModel.addComponentRequested(component.typeName)
            showsComponentPicker = false
        }) {
            HStack(alignment: .top, spacing: 7) {
                Text("+")
                    .font(.system(size: 13))
                    .foregroundColor(theme.editorColors.blue)
                    .frame(width: 12)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(component.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(theme.editorColors.text)
                        Spacer()
                        Text(component.category)
                            .font(.system(size: 9))
                            .foregroundColor(theme.editorColors.muted)
                    }
                    Text(component.description)
                        .font(.system(size: 9))
                        .foregroundColor(theme.editorColors.muted)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surface))
        }
        .buttonStyle(DefaultButtonStyle())
        .accessibilityIdentifier("AdaEditor.Inspector.AddComponent.\(component.typeName)")
    }

    func scriptableObjectEditor(_ object: EditorInspectorSidebarViewModel.ScriptableObjectSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(object.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                Spacer()
                Button(action: { viewModel.removeScriptableObjectRequested(object.identifier) }) {
                    Text("\u{E872}")
                        .font(AdaEditorMaterialSymbolFont.font(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(DefaultButtonStyle())
            }
            ForEach(object.fields, id: \.field.id) { field in
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel(field.field.label)
                    fieldControl(
                        fieldID: "\(object.identifier).\(field.field.key)",
                        value: field.value,
                        kind: field.field.kind,
                        isEditable: field.field.isEditable,
                        scalarBinding: viewModel.scriptableObjectFieldBinding(identifier: object.identifier, field: field.field),
                        axisBinding: { _ in viewModel.scriptableObjectFieldBinding(identifier: object.identifier, field: field.field) }
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }

    func addScriptableObjectButton(_ descriptor: EditorScriptableObjectDescriptor) -> some View {
        Button(action: { viewModel.addScriptableObjectRequested(descriptor) }) {
            HStack(spacing: 6) {
                Text("+")
                    .foregroundColor(theme.editorColors.purple)
                Text(descriptor.name)
                    .foregroundColor(theme.editorColors.text)
                Spacer()
                Text(descriptor.sourcePath)
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surface))
        }
        .buttonStyle(DefaultButtonStyle())
        .accessibilityIdentifier("AdaEditor.Inspector.AddScriptableObject.\(descriptor.identifier)")
    }
}
