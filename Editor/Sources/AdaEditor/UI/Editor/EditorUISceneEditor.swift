@_spi(AdaEngine) import AdaEngine

struct EditorUISceneEditor: View {
    let model: EditorUISceneModel
    @Environment(\.theme) private var theme
    @State private var modifierSearch = ""
    @State private var draggedID: String?

    var body: some View {
        GeometryReader { geometry in
            let footerHeight: Float = (model.error == nil ? 0 : 44) + (model.lastAction == nil ? 0 : 24)
            let contentHeight = max(0, geometry.size.height - 44 - footerHeight)
            let paletteWidth: Float = geometry.size.width < 1050 ? 140 : 170
            let hierarchyWidth: Float = geometry.size.width < 1050 ? 150 : 190
            let inspectorWidth: Float = geometry.size.width < 1050 ? 210 : 240
            let canvasWidth = max(0, geometry.size.width - paletteWidth - hierarchyWidth - inspectorWidth - 3)
            VStack(spacing: 0) {
                controls.frame(width: geometry.size.width, height: 44, alignment: .topLeading)
                if model.showsSource {
                    TextEditor(text: Binding(get: { model.rawSource }, set: { model.editSource($0) }))
                        .disabled(model.isReadOnly)
                        .frame(width: geometry.size.width, height: contentHeight)
                } else {
                    HStack(alignment: .top, spacing: 1) {
                        palette.frame(width: paletteWidth, height: contentHeight, alignment: .topLeading)
                            .accessibilityIdentifier("AdaEditor.UIScene.PalettePanel")
                        hierarchy.frame(width: hierarchyWidth, height: contentHeight, alignment: .topLeading)
                            .accessibilityIdentifier("AdaEditor.UIScene.HierarchyPanel")
                        canvas.frame(width: canvasWidth, height: contentHeight, alignment: .topLeading)
                            .accessibilityIdentifier("AdaEditor.UIScene.CanvasPanel")
                        inspector.frame(width: inspectorWidth, height: contentHeight, alignment: .topLeading)
                            .accessibilityIdentifier("AdaEditor.UIScene.InspectorPanel")
                    }
                    .frame(width: geometry.size.width, height: contentHeight, alignment: .topLeading)
                }
                if let error = model.error {
                    Text(error).foregroundColor(.red).font(.system(size: 12)).lineLimit(2)
                        .padding(8).frame(width: geometry.size.width, height: 44, alignment: .leading)
                }
                if let action = model.lastAction {
                    Text("Action: \(action)").font(.system(size: 11)).padding(4)
                        .frame(width: geometry.size.width, height: 24, alignment: .leading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .foregroundColor(theme.editorColors.text)
        .textFieldStyle(PlainTextFieldStyle())
        .background(theme.editorColors.surface)
        .accessibilityIdentifier("AdaEditor.UIScene")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(model.isInteractive ? "Interact" : "Design") { model.isInteractive.toggle() }
                .accessibilityIdentifier("AdaEditor.UIScene.Mode")
            Button("Undo") { model.undo() }.disabled(!model.canUndo)
            Button("Redo") { model.redo() }.disabled(!model.canRedo)
            Button(model.showsSource ? "Designer" : "YAML") { model.showsSource.toggle() }
            Spacer()
            Text("Size")
            TextField("Width", text: floatBinding(\.width)).frame(width: 60)
            Text("×")
            TextField("Height", text: floatBinding(\.height)).frame(width: 60)
            Button("−") { model.zoom = max(0.25, model.zoom - 0.25) }
            Text("\(Int(model.zoom * 100))%")
            Button("+") { model.zoom = min(3, model.zoom + 0.25) }
        }
        .font(.system(size: 12))
        .padding(8)
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Components").font(.system(size: 13, weight: .bold))
            SearchBar(text: Binding(get: { model.search }, set: { model.search = $0 }), prompt: "Find component")
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(model.palette) { signature in
                        Button(signature.name) { model.add(signature.id) }
                            .accessibilityIdentifier("AdaEditor.UIScene.Add.\(signature.id)")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(8)
    }

    private var hierarchy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hierarchy").font(.system(size: 13, weight: .bold))
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(rows, id: \.node.id) { row in
                        Button {
                            model.selectedID = row.node.id
                        } label: {
                            Text(row.node.type)
                                .font(.system(size: 12))
                                .foregroundColor(model.selectedID == row.node.id ? theme.editorColors.blue : theme.editorColors.text)
                                .padding(.leading, Float(row.depth * 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 26)
                        }
                        .accessibilityIdentifier("AdaEditor.UIScene.Node.\(row.node.id)")
                        .gesture(DragGesture(minimumDistance: 8).onEnded { value in
                            let currentRows = rows
                            guard let index = currentRows.firstIndex(where: { $0.node.id == row.node.id }) else { return }
                            let destination = min(max(index + Int((value.translation.height / 28).rounded()), 0), currentRows.count - 1)
                            let target = currentRows[destination]
                            if value.translation.width > 20 { model.move(row.node.id, into: target.node.id) }
                            else if let parent = target.parentID, let parentNode = currentRows.first(where: { $0.node.id == parent })?.node,
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
                }
            }
            HStack(spacing: 6) {
                Button("↑") { model.reorder(-1) }
                Button("↓") { model.reorder(1) }
                Button("Copy") { model.duplicateSelected() }
                Button("−") { model.removeSelected() }
            }
            Text("Wrap in").font(.system(size: 11))
            HStack(spacing: 4) {
                ForEach(["VStack", "HStack", "ZStack", "Grid"], id: \.self) { type in
                    Button(type) { model.wrap(type) }.font(.system(size: 10))
                }
            }
        }.padding(8)
    }

    private var canvas: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 8) {
                if let preview = model.preview {
                    EditorUISceneSurface(preview: preview, model: model)
                        .frame(width: model.width * model.zoom, height: model.height * model.zoom)
                        .background(Color.white)
                        .border(theme.editorColors.border)
                        .accessibilityIdentifier("AdaEditor.UIScene.Canvas")
                } else {
                    Text("UI preview unavailable").foregroundColor(theme.editorColors.muted)
                }
            }.padding(20)
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let node = model.selectedNode, let signature = model.signature(for: node) {
                    Text(signature.name).font(.system(size: 14, weight: .bold))
                    if node.type == "UI" { Button("Open UI source") { model.openNestedUI() } }
                    if node.id == model.document.root.id { inputDeclarations }
                    ForEach(signature.parameters, id: \.name) { parameter in
                        parameterEditor(parameter, argument: node.arguments[parameter.name]) { argument in
                            model.updateSelected { $0.arguments[parameter.name] = argument }
                        }
                    }
                    ForEach(signature.actions, id: \.name) { action in
                        Text("Action · \(action.name)").font(.system(size: 11))
                        TextField("Handler name", text: Binding(
                            get: { model.selectedNode?.actions[action.name] ?? "" },
                            set: { value in model.updateSelected { $0.actions[action.name] = value.isEmpty ? nil : value } }
                        ))
                    }
                    Divider()
                    Text("Modifiers · applied in order").font(.system(size: 12, weight: .bold))
                    ForEach(node.modifiers) { modifier in modifierEditor(modifier) }
                    SearchBar(text: $modifierSearch, prompt: "Add modifier")
                    ForEach(model.catalog.modifierSignatures.filter { modifierSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(modifierSearch) }) { signature in
                        Button("+ \(signature.name)") { model.addModifier(signature.id) }.font(.system(size: 11))
                    }
                }
            }.padding(8)
        }.disabled(model.isReadOnly)
    }

    private var inputDeclarations: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("UI inputs / preview data").font(.system(size: 12, weight: .bold))
            ForEach(model.document.inputs, id: \.name) { input in
                HStack {
                    TextField("Name", text: Binding(get: { input.name }, set: { name in
                        model.edit { document in if let index = document.inputs.firstIndex(where: { $0.name == input.name }) { document.inputs[index].name = name } }
                    }))
                    Button("×") { model.edit { $0.inputs.removeAll { $0.name == input.name } } }
                }
                TextField("Default (JSON)", text: Binding(get: { Self.format(input.defaultValue ?? .null) }, set: { text in
                    guard let value = Self.parse(text, type: input.type) else { return }
                    model.edit { document in if let index = document.inputs.firstIndex(where: { $0.name == input.name }) { document.inputs[index].defaultValue = value } }
                    model.session?.context.set(input.name, to: value)
                }))
                HStack(spacing: 4) {
                    ForEach(UIValueType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            model.edit { document in
                                if let index = document.inputs.firstIndex(where: { $0.name == input.name }) {
                                    document.inputs[index].type = type
                                    document.inputs[index].defaultValue = Self.defaultValue(type)
                                }
                            }
                        }.font(.system(size: 9))
                    }
                }
            }
            Button("+ Input") { model.edit { $0.inputs.append(.init("input\($0.inputs.count + 1)", type: .string, defaultValue: .string(""))) } }
            ForEach(model.document.actions, id: \.name) { action in
                HStack {
                    TextField("Action name", text: Binding(get: { action.name }, set: { name in
                        model.edit { document in if let index = document.actions.firstIndex(where: { $0.name == action.name }) { document.actions[index].name = name } }
                    }))
                    Button("×") { model.edit { $0.actions.removeAll { $0.name == action.name } } }
                }
            }
            Button("+ Action") { model.edit { $0.actions.append(.init("action\($0.actions.count + 1)")) } }
        }
    }

    private static func defaultValue(_ type: UIValueType) -> UIValue {
        switch type { case .string: .string(""); case .number: .number(0); case .bool: .bool(false); case .array: .array([]); case .object: .object([:]); case .any: .null }
    }

    private func modifierEditor(_ modifier: UIModifierDescription) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(modifier.type).font(.system(size: 12, weight: .bold))
                Spacer()
                Button("↑") { moveModifier(modifier.id, -1) }
                Button("↓") { moveModifier(modifier.id, 1) }
                Button("×") { model.updateSelected { $0.modifiers.removeAll { $0.id == modifier.id } } }
            }
            if let signature = model.catalog.modifiers[modifier.type]?.signature {
                if signature.content != .none {
                    Button("Add content from palette") { model.insertionModifierID = modifier.id }
                }
                ForEach(signature.parameters, id: \.name) { parameter in
                    parameterEditor(parameter, argument: modifier.arguments[parameter.name]) { value in
                        model.updateSelected { node in
                            if let index = node.modifiers.firstIndex(where: { $0.id == modifier.id }) { node.modifiers[index].arguments[parameter.name] = value }
                        }
                    }
                }
                ForEach(signature.actions, id: \.name) { action in
                    TextField(action.name, text: Binding(get: { modifier.actions[action.name] ?? "" }, set: { value in
                        model.updateSelected { node in
                            if let index = node.modifiers.firstIndex(where: { $0.id == modifier.id }) { node.modifiers[index].actions[action.name] = value.isEmpty ? nil : value }
                        }
                    }))
                }
            }
        }.padding(6).border(theme.editorColors.border)
    }

    private func parameterEditor(_ parameter: UIParameter, argument: UIArgument?, onChange: @escaping (UIArgument) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(parameter.name).font(.system(size: 11))
                Spacer()
                Button(argument?.binding == nil ? "Value" : "Binding") {
                    onChange(argument?.binding == nil ? UIArgument(binding: parameter.name) : UIArgument(value: parameter.defaultValue ?? .string("")))
                }.font(.system(size: 10))
            }
            TextField(parameter.type.rawValue, text: Binding(get: {
                argument?.binding ?? Self.format(argument?.value ?? parameter.defaultValue ?? .null)
            }, set: { value in
                if argument?.binding != nil { if !value.isEmpty { onChange(.init(binding: value)) }; return }
                if let parsed = Self.parse(value, type: parameter.type) { onChange(.init(value: parsed)) }
            }))
            .accessibilityIdentifier("AdaEditor.UIScene.Parameter.\(parameter.name)")
        }
    }

    private func moveModifier(_ id: String, _ direction: Int) {
        model.updateSelected { node in
            guard let index = node.modifiers.firstIndex(where: { $0.id == id }), node.modifiers.indices.contains(index + direction) else { return }
            node.modifiers.swapAt(index, index + direction)
        }
    }

    private func floatBinding(_ key: ReferenceWritableKeyPath<EditorUISceneModel, Float>) -> Binding<String> {
        Binding(get: { String(Int(model[keyPath: key])) }, set: { if let value = Float($0), value.isFinite, value >= 100, value <= 8192 { model[keyPath: key] = value } })
    }

    private var rows: [Row] {
        func flatten(_ node: UINodeDescription, depth: Int, parentID: String?) -> [Row] {
            [Row(node: node, depth: depth, parentID: parentID)]
                + node.children.flatMap { flatten($0, depth: depth + 1, parentID: node.id) }
                + node.modifiers.flatMap { $0.children.flatMap { flatten($0, depth: depth + 1, parentID: nil) } }
        }
        return flatten(model.document.root, depth: 0, parentID: nil)
    }
    private struct Row { let node: UINodeDescription; let depth: Int; let parentID: String? }

    static func format(_ value: UIValue) -> String {
        if let string = value.string { return string }
        if let data = try? JSONEncoder().encode(value) { return String(decoding: data, as: UTF8.self) }
        return ""
    }
    static func parse(_ text: String, type: UIValueType) -> UIValue? {
        if type == .string { return .string(text) }
        return try? JSONDecoder().decode(UIValue.self, from: Data(text.utf8))
    }
}
