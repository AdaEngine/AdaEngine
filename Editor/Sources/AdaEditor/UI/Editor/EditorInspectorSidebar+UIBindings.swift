@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorInspectorSidebar {
    func scriptUIBindingsEditor(_ field: EditorInspectorSidebarViewModel.ComponentField) -> some View {
        let mappings = viewModel.uiScriptBindings
        let inputs = viewModel.uiBindingInputNames
        let scripts = viewModel.selectedEntity?.scriptableObjects ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("Connect UI inputs to exported fields on this entity.")
                .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
            ForEach(mappings.keys.sorted(), id: \.self) { input in
                if let mapping = mappings[input] {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            EditorEnumField(cases: inputs.filter { $0 == input || mappings[$0] == nil }, selection: Binding(
                                get: { input }, set: { viewModel.renameUIBinding(input, to: $0) }
                            ))
                            Button("−") { viewModel.setUIBinding(input, to: nil) }
                                .accessibilityIdentifier("AdaEditor.UIBinding.Remove.\(input)")
                        }
                        EditorEnumField(cases: scripts.map(\.identifier), selection: Binding(
                            get: { mapping.script }, set: { identifier in
                                let firstField = scripts.first { $0.identifier == identifier }?.fields.first?.field.key ?? ""
                                viewModel.setUIBinding(input, to: .init(script: identifier, field: firstField))
                            }
                        ))
                        EditorEnumField(cases: scripts.first { $0.identifier == mapping.script }?.fields.map(\.field.key) ?? [], selection: Binding(
                            get: { mapping.field }, set: { viewModel.setUIBinding(input, to: .init(script: mapping.script, field: $0)) }
                        ))
                        if let issue = viewModel.uiBindingIssue(input: input, mapping: mapping) {
                            Text(issue).font(.system(size: 11)).foregroundColor(.red)
                        }
                    }
                    .accessibilityIdentifier("AdaEditor.UIBinding.\(input)")
                }
            }
            if let input = inputs.first(where: { mappings[$0] == nil }),
               let script = scripts.first(where: { !$0.fields.isEmpty }), let exported = script.fields.first {
                Button("+ Binding") {
                    viewModel.setUIBinding(input, to: .init(script: script.identifier, field: exported.field.key))
                }.accessibilityIdentifier("AdaEditor.UIBinding.Add")
            } else if mappings.isEmpty {
                Text("Choose a .ui with declared Inputs and attach a script with @export fields.")
                    .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
            }
        }
    }
}

extension EditorInspectorSidebarViewModel {
    private var uiFields: [ComponentField] {
        selectedEntity?.components.first { $0.typeName == EditorBuiltInComponentType.uiComponent }?.fields ?? []
    }

    var uiScriptBindings: [String: UIScriptFieldBinding] {
        let text = uiFields.first { $0.field.key == "scriptBindings" }?.value ?? "{}"
        return (try? JSONDecoder().decode([String: UIScriptFieldBinding].self, from: Data(text.utf8))) ?? [:]
    }

    var uiBindingInputs: [UIParameter] {
        guard let path = uiFields.first(where: { $0.field.key == "path" })?.value,
              let file = uiSceneFiles[path],
              let source = try? String(contentsOfFile: file, encoding: .utf8),
              let document = try? UISceneDocument.decode(source) else { return [] }
        return document.inputs
    }

    var uiBindingInputNames: [String] { uiBindingInputs.map(\.name) }

    func setUIBinding(_ input: String, to mapping: UIScriptFieldBinding?) {
        var mappings = uiScriptBindings
        mappings[input] = mapping
        saveUIBindings(mappings)
    }

    func renameUIBinding(_ input: String, to name: String) {
        guard input != name, uiBindingInputNames.contains(name) else { return }
        var mappings = uiScriptBindings
        guard mappings[name] == nil, let mapping = mappings.removeValue(forKey: input) else { return }
        mappings[name] = mapping
        saveUIBindings(mappings)
    }

    func uiBindingIssue(input: String, mapping: UIScriptFieldBinding) -> String? {
        if let name = uiFields.first(where: { $0.field.key == "contextName" })?.value, !name.isEmpty {
            return "Clear Data context to use this entity's script fields."
        }
        guard let parameter = uiBindingInputs.first(where: { $0.name == input }) else { return "UI input '\(input)' is missing. Declare it in the UI Editor." }
        guard let script = selectedEntity?.scriptableObjects.first(where: { $0.identifier == mapping.script }),
              let field = script.fields.first(where: { $0.field.key == mapping.field }) else { return "Attach the script or select an existing exported field." }
        let expected: UIValueType?
        switch field.field.kind {
        case .string: expected = .string
        case .bool: expected = .bool
        case .float, .int: expected = .number
        default: expected = nil
        }
        if let expected, parameter.type != .any, parameter.type != expected { return "Input is \(parameter.type.rawValue); field is \(expected.rawValue)." }
        return nil
    }

    private func saveUIBindings(_ mappings: [String: UIScriptFieldBinding]) {
        guard let field = uiFields.first(where: { $0.field.key == "scriptBindings" }),
              let data = try? JSONEncoder().encode(mappings), let text = String(data: data, encoding: .utf8) else { return }
        componentFieldBinding(typeName: field.typeName, field: field.field).wrappedValue = text
    }
}
