@_spi(AdaEngine) import AdaEngine

struct EditorUISceneEditor: View {
    let model: EditorUISceneModel
    @Environment(\.theme) var theme
    @State var modifierSearch = ""
    @State var libraryTab = "Components"
    @State var compactPane: EditorUIDesignerPane = .canvas
    @State var showsModifierLibrary = false
    @State var showsInputs = false
    @State var fitsCanvas = true

    var body: some View { designerBody }

    var inputDeclarations: some View {
        VStack(alignment: .leading, spacing: 5) {
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
                ScrollView(.horizontal) {
                    HStack(spacing: 2) {
                        ForEach(UIValueType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                model.edit { document in
                                    if let index = document.inputs.firstIndex(where: { $0.name == input.name }) {
                                        document.inputs[index].type = type
                                        document.inputs[index].defaultValue = Self.defaultValue(type)
                                    }
                                }
                            }.buttonStyle(EditorUIDesignerButtonStyle(colors: theme.editorColors, selected: input.type == type))
                        }
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

    static func defaultValue(_ type: UIValueType) -> UIValue {
        switch type { case .string: .string(""); case .number: .number(0); case .bool: .bool(false); case .array: .array([]); case .object: .object([:]); case .any: .null }
    }

    func modifierEditor(_ modifier: UIModifierDescription) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(modifier.type).font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                iconButton("\u{E5D8}", title: "Modifier.Up.\(modifier.id)") { moveModifier(modifier.id, -1) }
                iconButton("\u{E5DB}", title: "Modifier.Down.\(modifier.id)") { moveModifier(modifier.id, 1) }
                iconButton("\u{E5CD}", title: "Modifier.Remove.\(modifier.id)") { model.updateSelected { $0.modifiers.removeAll { $0.id == modifier.id } } }
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
        }
        .padding(10)
        .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.surfaceElevated.opacity(0.45)))
        .overlay { RoundedRectangleShape(cornerRadius: 8).stroke(theme.editorColors.border.opacity(0.6), lineWidth: 1) }
    }

    func parameterEditor(_ parameter: UIParameter, argument: UIArgument?, onChange: @escaping (UIArgument) -> Void) -> some View {
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

    func moveModifier(_ id: String, _ direction: Int) {
        model.updateSelected { node in
            guard let index = node.modifiers.firstIndex(where: { $0.id == id }), node.modifiers.indices.contains(index + direction) else { return }
            node.modifiers.swapAt(index, index + direction)
        }
    }

    func floatBinding(_ key: ReferenceWritableKeyPath<EditorUISceneModel, Float>) -> Binding<String> {
        Binding(get: { String(Int(model[keyPath: key])) }, set: { if let value = Float($0), value.isFinite, value >= 100, value <= 8192 { model[keyPath: key] = value } })
    }

    var rows: [Row] {
        func flatten(_ node: UINodeDescription, depth: Int, parentID: String?) -> [Row] {
            [Row(node: node, depth: depth, parentID: parentID)]
                + node.children.flatMap { flatten($0, depth: depth + 1, parentID: node.id) }
                + node.modifiers.flatMap { $0.children.flatMap { flatten($0, depth: depth + 1, parentID: nil) } }
        }
        return flatten(model.document.root, depth: 0, parentID: nil)
    }
    struct Row { let node: UINodeDescription; let depth: Int; let parentID: String? }

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
