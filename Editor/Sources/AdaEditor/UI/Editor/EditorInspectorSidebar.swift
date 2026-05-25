@_spi(AdaEngine) import AdaEngine

struct EditorInspectorSidebar: View {
    let viewModel: EditorInspectorSidebarViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle("INSPECTOR", trailing: "", theme: theme)
            inspectorSection("SCENE") {
                Button(action: { viewModel.addEntityRequested() }) {
                    Text("+ Entity")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.blue)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangleShape(cornerRadius: 4).fill(theme.editorColors.blue.opacity(0.12)))
                }
                .buttonStyle(DefaultButtonStyle())
            }
            if let selectedEntity = viewModel.selectedEntity {
                inspectorSection(selectedEntity.name.uppercased()) {
                    Text(selectedEntity.editorID)
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.muted)
                }
                inspectorSection("TRANSFORM") {
                    ForEach(selectedEntity.transformFields, id: \.label) { field in
                        transformRow(field)
                    }
                }
                inspectorSection("COMPONENTS") {
                    ForEach(selectedEntity.components, id: \.typeName) { component in
                        componentEditor(component)
                    }
                }
                inspectorSection("GIZMO") {
                    gizmoEditor(selectedEntity)
                }
            } else {
                inspectorSection("SELECTION") {
                    Text("No entity selected")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.muted)
                }
            }
            Spacer()
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12)).foregroundColor(theme.editorColors.blue)
            content()
        }
        .padding(12)
    }

    private func transformRow(_ field: EditorInspectorSidebarViewModel.TransformField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(field.label)
            fieldControl(
                value: field.value,
                kind: field.field.kind,
                isEditable: field.field.isEditable,
                scalarBinding: viewModel.transformFieldBinding(field),
                axisBinding: { viewModel.transformVectorAxisBinding(field: field, axisIndex: $0) }
            )
        }
    }

    private func componentEditor(_ component: EditorInspectorSidebarViewModel.ComponentSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(component.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                Spacer()
                if component.canRemove {
                    Button(action: { viewModel.removeComponentRequested(component.typeName) }) {
                        Text("Remove")
                            .font(.system(size: 10))
                            .foregroundColor(theme.editorColors.muted)
                    }
                    .buttonStyle(DefaultButtonStyle())
                }
            }

            ForEach(component.fields, id: \.field.id) { field in
                componentFieldRow(field)
            }
        }
        .padding(.vertical, 6)
    }

    private func componentFieldRow(_ field: EditorInspectorSidebarViewModel.ComponentField) -> some View {
        HStack(spacing: 6) {
            fieldLabel(field.field.label)
            fieldControl(
                value: field.value,
                kind: field.field.kind,
                isEditable: field.field.isEditable,
                scalarBinding: viewModel.componentFieldBinding(typeName: field.typeName, field: field.field),
                axisBinding: { viewModel.componentVectorAxisBinding(typeName: field.typeName, field: field.field, axisIndex: $0) }
            )
        }
    }

    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11))
            .foregroundColor(theme.editorColors.muted)
            .frame(width: 82, alignment: .leading)
    }

    @ViewBuilder
    private func fieldControl(
        value: String,
        kind: EditorComponentFieldKind,
        isEditable: Bool,
        scalarBinding: Binding<String>,
        axisBinding: @escaping (Int) -> Binding<String>
    ) -> some View {
        if let axes = axisLabels(for: kind) {
            vectorField(axes: axes, value: value, isEditable: isEditable, axisBinding: axisBinding)
        } else if case .bool = kind, isEditable {
            boolField(text: scalarBinding)
        } else if case .enumeration(let cases) = kind, isEditable {
            enumField(cases: cases, text: scalarBinding)
        } else if case .color = kind, isEditable {
            colorField(value: value, text: scalarBinding)
        } else if isEditable {
            editorTextField(text: scalarBinding)
        } else {
            readonlyField(value)
        }
    }
    
    private func vectorField(
        axes: [String],
        value: String,
        isEditable: Bool,
        axisBinding: @escaping (Int) -> Binding<String>
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(axes.indices), id: \.self) { index in
                vectorAxisField(
                    label: axes[index],
                    value: vectorDisplayValue(from: value, index: index),
                    isEditable: isEditable,
                    text: axisBinding(index)
                )
            }
        }
        .frame(height: 26)
        .frame(maxWidth: .infinity)
    }

    private func vectorAxisField(label: String, value: String, isEditable: Bool, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.blue.opacity(0.78))
                .frame(width: 10)
            if isEditable {
                TextField("", text: text)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(PlainTextFieldStyle())
            } else {
                Text(value)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 6)
        .background(RoundedRectangleShape(cornerRadius: 5).fill(isEditable ? theme.editorColors.surface : theme.editorColors.surfaceElevated))
        .overlay { RoundedRectangleShape(cornerRadius: 5).stroke(theme.editorColors.border.opacity(0.92), lineWidth: 1) }
    }

    private func editorTextField(text: Binding<String>) -> some View {
        TextField("", text: text)
            .font(.system(size: 11))
            .foregroundColor(theme.editorColors.text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surface))
        .overlay { RoundedRectangleShape(cornerRadius: 5).stroke(theme.editorColors.border.opacity(0.92), lineWidth: 1) }
    }

    private func boolField(text: Binding<String>) -> some View {
        Button(action: {
            text.wrappedValue = text.wrappedValue == "true" ? "false" : "true"
        }) {
            Text(text.wrappedValue == "true" ? "On" : "Off")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .frame(height: 26)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surface))
                .overlay { RoundedRectangleShape(cornerRadius: 5).stroke(theme.editorColors.border.opacity(0.92), lineWidth: 1) }
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func enumField(cases: [String], text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(cases, id: \.self) { item in
                Button(action: { text.wrappedValue = item }) {
                    Text(item)
                        .font(.system(size: 10))
                        .foregroundColor(text.wrappedValue == item ? theme.editorColors.text : theme.editorColors.muted)
                        .padding(.horizontal, 6)
                        .frame(height: 26)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(text.wrappedValue == item ? theme.editorColors.blue.opacity(0.18) : theme.editorColors.surface))
                        .overlay { RoundedRectangleShape(cornerRadius: 5).stroke(theme.editorColors.border.opacity(0.92), lineWidth: 1) }
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func colorField(value: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            RectangleShape()
                .fill(colorPreview(from: value))
                .frame(width: 24, height: 24)
                .overlay { RoundedRectangleShape(cornerRadius: 5).stroke(theme.editorColors.border.opacity(0.92), lineWidth: 1) }
            editorTextField(text: text)
        }
        .frame(maxWidth: .infinity)
    }

    private func colorPreview(from value: String) -> Color {
        let components = value
            .split { $0 == "," || $0 == " " || $0 == "\t" }
            .map { Float($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        return Color(
            red: components.indices.contains(0) ? components[0] : 0,
            green: components.indices.contains(1) ? components[1] : 0,
            blue: components.indices.contains(2) ? components[2] : 0,
            alpha: components.indices.contains(3) ? components[3] : 1
        )
    }

    private func readonlyField(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11))
            .foregroundColor(theme.editorColors.muted)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surfaceElevated))
            .overlay { RoundedRectangleShape(cornerRadius: 5).stroke(theme.editorColors.border.opacity(0.60), lineWidth: 1) }
    }

    private func axisLabels(for kind: EditorComponentFieldKind) -> [String]? {
        switch kind {
        case .vector2:
            return ["X", "Y"]
        case .vector3:
            return ["X", "Y", "Z"]
        case .vector4:
            return ["X", "Y", "Z", "W"]
        default:
            return nil
        }
    }

    private func vectorDisplayValue(from value: String, index: Int) -> String {
        let components = value
            .split { $0 == "," || $0 == " " || $0 == "\t" }
            .map { String($0) }
        guard components.indices.contains(index) else {
            return "0"
        }
        return components[index]
    }

    private func gizmoEditor(_ selectedEntity: EditorInspectorSidebarViewModel.SelectedEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedEntity.hasExplicitGizmo {
                Button(action: { viewModel.toggleGizmoEnabled() }) {
                    Text((selectedEntity.gizmo?.isEnabled ?? false) ? "Enabled" : "Disabled")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.text)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangleShape(cornerRadius: 4).fill(theme.editorColors.blue.opacity(0.16)))
                }
                .buttonStyle(DefaultButtonStyle())

                TextField("Name", text: viewModel.gizmoNameBinding)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RoundedRectangleShape(cornerRadius: 4).fill(theme.editorColors.surface))
                    .overlay { RoundedRectangleShape(cornerRadius: 4).stroke(theme.editorColors.border, lineWidth: 1) }

                HStack(spacing: 4) {
                    ForEach(EditorGizmoKind.allCases, id: \.rawValue) { kind in
                        gizmoKindButton(kind, active: selectedEntity.gizmo?.kind == kind)
                    }
                }
            } else {
                Button(action: { viewModel.addGizmo() }) {
                    Text("Add Gizmo")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.blue)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangleShape(cornerRadius: 4).fill(theme.editorColors.blue.opacity(0.12)))
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
    }

    private func gizmoKindButton(_ kind: EditorGizmoKind, active: Bool) -> some View {
        Button(action: { viewModel.setGizmoKind(kind) }) {
            Text(kind.rawValue)
                .font(.system(size: 10))
                .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(RoundedRectangleShape(cornerRadius: 4).fill(active ? theme.editorColors.purple.opacity(0.18) : theme.editorColors.surface))
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func shortComponentName(_ componentName: String) -> String {
        componentName.components(separatedBy: ".").last ?? componentName
    }
}
