@_spi(AdaEngine) import AdaEngine

extension EditorUISceneEditor {
    var designerLibrary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(["Components", "Layers"], id: \.self) { tab in
                    Button(tab) { libraryTab = tab }
                        .buttonStyle(EditorUIDesignerButtonStyle(colors: theme.editorColors, selected: libraryTab == tab))
                        .accessibilityIdentifier("AdaEditor.UIScene.Library.\(tab)")
                }
                Spacer()
            }.frame(height: 32).padding(10)
            panelDivider
            if libraryTab == "Components" {
                AnyView(componentLibrary).frame(maxHeight: .infinity)
            } else {
                AnyView(layerLibrary).frame(maxHeight: .infinity)
            }
        }
        .background(theme.editorColors.surface)
        .accessibilityIdentifier("AdaEditor.UIScene.Library")
    }

    var componentLibrary: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorUIDesignerField(placeholder: "Find component…", text: Binding(get: { model.search }, set: { model.search = $0 }))
                .accessibilityIdentifier("AdaEditor.UIScene.ComponentSearch")
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    if model.palette.isEmpty {
                        Text("No matching components").foregroundColor(theme.editorColors.muted).font(.system(size: 12)).padding(.vertical, 12)
                    }
                    ForEach(["Layout", "Content", "Controls", "Drawing", "Advanced"], id: \.self) { category in
                        let items = model.palette.filter { EditorUIDesignerSymbols.category($0.id) == category }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                sectionTitle(category, detail: String(items.count)).padding(.horizontal, 6)
                                ForEach(items) { signature in
                                    Button { model.add(signature.id) } label: {
                                        HStack(spacing: 10) {
                                            symbol(EditorUIDesignerSymbols.icon(signature.id))
                                                .foregroundColor(theme.editorColors.muted)
                                            Text(signature.name).lineLimit(1)
                                            Spacer()
                                            symbol("\u{E145}", size: 12).foregroundColor(theme.editorColors.muted.opacity(0.6))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .disabled(model.isReadOnly)
                                    .accessibilityIdentifier("AdaEditor.UIScene.Add.\(signature.id)")
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: .infinity)
            Text("Click to add to the selected layer")
                .font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
        }.padding(10)
    }

    var layerLibrary: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Document", detail: "\(rows.count) layers").padding(.horizontal, 8)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(rows, id: \.node.id) { row in
                        layerRow(row)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: .infinity)
            panelDivider
            HStack(spacing: 4) {
                iconButton("\u{E5D8}", title: "Layer.Up") { model.reorder(-1) }
                iconButton("\u{E5DB}", title: "Layer.Down") { model.reorder(1) }
                Spacer()
                iconButton("\u{E14D}", title: "Layer.Duplicate", action: model.duplicateSelected)
                iconButton("\u{E872}", title: "Layer.Delete", action: model.removeSelected)
            }.disabled(model.isReadOnly || model.selectedID == model.document.root.id)
            Text("Wrap selection in").font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 2) {
                    ForEach(["VStack", "HStack", "ZStack", "Grid"], id: \.self) { type in
                        Button(type) { model.wrap(type) }
                            .accessibilityIdentifier("AdaEditor.UIScene.Wrap.\(type)")
                    }
                }.disabled(model.isReadOnly)
            }
        }.padding(10)
    }

    func layerRow(_ row: Row) -> some View {
        Button { model.selectedID = row.node.id } label: {
            HStack(spacing: 7) {
                symbol(EditorUIDesignerSymbols.icon(row.node.type), size: 14)
                Text(row.node.type).lineLimit(1)
                Spacer()
                if row.parentID == nil, row.depth == 0 {
                    Text("ROOT").font(.system(size: 9, weight: .semibold)).foregroundColor(theme.editorColors.muted)
                }
            }.padding(.leading, Float(min(row.depth, 8) * 12)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(EditorUIDesignerButtonStyle(colors: theme.editorColors, selected: model.selectedID == row.node.id))
        .accessibilityIdentifier("AdaEditor.UIScene.Node.\(row.node.id)")
        .gesture(DragGesture(minimumDistance: 8).onEnded { value in
            let current = rows
            guard let index = current.firstIndex(where: { $0.node.id == row.node.id }) else { return }
            let destination = min(max(index + Int((value.translation.height / 32).rounded()), 0), current.count - 1)
            let target = current[destination]
            if value.translation.width > 20 { model.move(row.node.id, into: target.node.id) }
            else if let parent = target.parentID, let parentNode = current.first(where: { $0.node.id == parent })?.node,
                    let childIndex = parentNode.children.firstIndex(where: { $0.id == target.node.id }) {
                model.move(row.node.id, into: parent, at: childIndex)
            }
        })
        .contextMenu {
            Button("Move selected here") { model.move(model.selectedID, into: row.node.id) }
            Button("Duplicate") { model.selectedID = row.node.id; model.duplicateSelected() }
            Button("Delete") { model.selectedID = row.node.id; model.removeSelected() }
        }
    }

    var designerInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let node = model.selectedNode, let signature = model.signature(for: node) {
                HStack(spacing: 10) {
                    symbol(EditorUIDesignerSymbols.icon(node.type), size: 20)
                        .foregroundColor(theme.editorColors.blue).padding(8)
                        .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.blue.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(signature.name).font(.system(size: 15, weight: .semibold))
                        Text(node.id == model.document.root.id ? "Root container" : "Selected layer")
                            .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                    }
                    Spacer()
                }.padding(14).frame(height: 76)
                panelDivider
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        if node.type == "UI" { Button("Open UI source") { model.openNestedUI() } }
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Properties", detail: String(signature.parameters.count))
                            if signature.parameters.isEmpty {
                                Text("This component has no properties.").font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                            }
                            ForEach(signature.parameters, id: \.name) { parameter in
                                parameterEditor(parameter, argument: node.arguments[parameter.name]) { argument in
                                    model.updateSelected { $0.arguments[parameter.name] = argument }
                                }
                            }
                            ForEach(signature.actions, id: \.name) { action in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(action.name).font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                                    EditorUIDesignerField(placeholder: "Handler name", text: Binding(
                                        get: { model.selectedNode?.actions[action.name] ?? "" },
                                        set: { value in model.updateSelected { $0.actions[action.name] = value.isEmpty ? nil : value } }
                                    ))
                                }
                            }
                        }
                        panelDivider
                        modifiersSection(node)
                        if node.id == model.document.root.id {
                            panelDivider
                            VStack(alignment: .leading, spacing: 8) {
                                Button { showsInputs.toggle() } label: {
                                    HStack {
                                        symbol(showsInputs ? "\u{E5CF}" : "\u{E5CC}", size: 14)
                                        Text("Inputs & actions").font(.system(size: 12, weight: .semibold))
                                        Spacer()
                                        Text(String(model.document.inputs.count + model.document.actions.count)).foregroundColor(theme.editorColors.muted)
                                    }
                                }.accessibilityIdentifier("AdaEditor.UIScene.Inputs.Toggle")
                                if showsInputs { inputDeclarations }
                            }
                        }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: .infinity)
                .disabled(model.isReadOnly)
            } else {
                Text("Select a layer to inspect").foregroundColor(theme.editorColors.muted).padding(16)
                Spacer()
            }
        }
        .textFieldStyle(EditorUIDesignerInspectorFieldStyle(colors: theme.editorColors))
        .background(theme.editorColors.surface)
        .accessibilityIdentifier("AdaEditor.UIScene.Inspector")
    }

    func modifiersSection(_ node: UINodeDescription) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Modifiers", detail: String(node.modifiers.count))
            if node.modifiers.isEmpty {
                Text("Add padding, color or a frame to style this layer.")
                    .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
            }
            ForEach(node.modifiers) { modifier in modifierEditor(modifier) }
            Button { showsModifierLibrary.toggle() } label: {
                HStack {
                    symbol(showsModifierLibrary ? "\u{E5CD}" : "\u{E145}", size: 14)
                    Text(showsModifierLibrary ? "Close library" : "Add modifier")
                    Spacer()
                }
            }
            .buttonStyle(EditorUIDesignerButtonStyle(colors: theme.editorColors, bordered: true))
            .accessibilityIdentifier("AdaEditor.UIScene.Modifiers.Toggle")
            if showsModifierLibrary {
                EditorUIDesignerField(placeholder: "Find modifier…", text: $modifierSearch)
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(model.catalog.modifierSignatures.filter { modifierSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(modifierSearch) }) { signature in
                            Button { model.addModifier(signature.id); showsModifierLibrary = false; modifierSearch = "" } label: {
                                HStack { Text(signature.name).lineLimit(1); Spacer(); symbol("\u{E145}", size: 12) }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.accessibilityIdentifier("AdaEditor.UIScene.Modifier.Add.\(signature.id)")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 220)
                .accessibilityIdentifier("AdaEditor.UIScene.Modifiers.Library")
            }
        }
    }
}

private struct EditorUIDesignerInspectorFieldStyle: TextFieldStyle {
    let colors: EditorThemeColors
    func _body(configuration: TextField) -> some View {
        PlainTextFieldStyle()._body(configuration: configuration)
            .font(.system(size: 12)).foregroundColor(colors.text)
            .padding(.horizontal, 6).frame(height: 30)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(colors.surfaceElevated))
            .overlay { RoundedRectangleShape(cornerRadius: 6).stroke(colors.border.opacity(0.6), lineWidth: 1) }
    }
}
