@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorShaderGraphEditor: View {
    let model: EditorShaderGraphModel
    var modelDocuments: [EditorAssetDocument] = []
    @Environment(\.theme) private var theme
    @State private var canvas = EditorNodeCanvasState()
    @State private var interaction: EditorNodeCanvasInteraction?
    @State private var showsInspector = true
    @State private var showsSource = false
    @State private var operation = "constant"
    @State private var valueType = "float"
    @State private var preview = EditorShaderGraphPreview()
    @State private var showsPreview = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                toolbar(size: geometry.size)
                HStack(spacing: 0) {
                    if showsSource {
                        ScrollView { Text(verbatim: (try? model.graph?.compileGLSL().source) ?? "").font(.system(size: 11)).foregroundColor(theme.editorColors.text).padding(12) }
                    } else {
                        EditorNodeCanvas(
                            items: model.canvasItems,
                            wires: model.canvasWires,
                            selection: model.selection,
                            state: canvas,
                            revision: model.layoutRevision &+ model.semanticRevision,
                            interaction: interaction
                        )
                    }
                    if showsInspector { inspector.frame(width: min(270, geometry.size.width * 0.45)) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let message = model.diagnosticMessage {
                    Button {
                        if let id = model.validation?.nodeID { model.selection = [id] }
                    } label: {
                        Text(verbatim: message).font(.system(size: 11)).foregroundColor(.red).lineLimit(3)
                    }.buttonStyle(DefaultButtonStyle()).padding(8)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.background(theme.editorColors.background).accessibilityIdentifier("AdaEditor.ShaderGraph.Editor").onAppear {
            interaction = model.canvasInteraction()
            preview.schedule(model.graph, basePath: model.url?.path)
        }.onChange(of: model.semanticRevision) { _, _ in preview.schedule(model.graph, basePath: model.url?.path) }.onDisappear {
            interaction?.abort()
            preview.cancel()
        }
    }

    private func toolbar(size: Size) -> some View {
        HStack(spacing: 8) {
            Button(L10n.text("Undo")) { model.undo() }.disabled(!model.canUndo)
            Button(L10n.text("Redo")) { model.redo() }.disabled(!model.canRedo)
            Button(L10n.text("Save")) { model.save() }.disabled(!model.isDirty || model.isReadOnly).accessibilityIdentifier("AdaEditor.ShaderGraph.Save")
            Button(L10n.text("Reload")) { model.reload() }
            Spacer(minLength: 4)
            Button("−") { canvas.zoom(by: 0.8, around: [size.width / 2, size.height / 2]) }
            Button("+") { canvas.zoom(by: 1.25, around: [size.width / 2, size.height / 2]) }
            Button(L10n.text("Fit")) { canvas.fit(model.canvasItems, in: Size(width: max(100, size.width - (showsInspector ? 270 : 0)), height: size.height - 48)) }
            Button(L10n.text("Pan")) { canvas.panMode.toggle() }
            Button(L10n.text("Source")) { showsSource.toggle() }
            Button(L10n.text("Preview")) { showsPreview.toggle() }
            Button(L10n.text("Inspector")) { showsInspector.toggle() }
        }.buttonStyle(DefaultButtonStyle()).font(.system(size: 11)).foregroundColor(theme.editorColors.text).padding(.horizontal, 8).frame(height: 36)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if showsPreview { previewPanel }
                Text(L10n.text("Add Node")).font(.system(size: 13, weight: .semibold))
                EditorEnumField(
                    cases: availableOperations.map { L10n.tr(EditorShaderGraphModel.operationTitle($0.rawValue)) },
                    selection: Binding(
                        get: { L10n.tr(EditorShaderGraphModel.operationTitle(operation)) },
                        set: { title in operation = availableOperations.first { L10n.tr(EditorShaderGraphModel.operationTitle($0.rawValue)) == title }?.rawValue ?? "constant" }
                    ),
                    accessibilityID: "AdaEditor.ShaderGraph.Operation"
                )
                EditorEnumField(cases: availableTypes, selection: $valueType, accessibilityID: "AdaEditor.ShaderGraph.Type")
                Button(L10n.text("Add Node")) { addNode() }.disabled(model.isReadOnly).accessibilityIdentifier("AdaEditor.ShaderGraph.AddNode")
                Divider()
                if let node = model.selectedNode { nodeInspector(node) } else { Text(L10n.text("Select a node to edit its properties.")).foregroundColor(theme.editorColors.muted) }
                Divider()
                if let graph = model.graph { outputInspector(graph) }
            }.padding(12)
        }.font(.system(size: 12)).foregroundColor(theme.editorColors.text).buttonStyle(DefaultButtonStyle()).background(theme.editorColors.surface)
    }

    private var availableOperations: [ShaderGraph.Operation] { ShaderGraph.Operation.allCases.filter { $0 != .output && ($0 != .spriteTexture || model.graph?.target == .sprite) } }

    private var availableTypes: [String] {
        switch ShaderGraph.Operation(rawValue: operation) {
        case .parameter: ["float", "bool", "vector2", "vector3", "vector4", "color", "texture2D"]
        case .constant: ["float", "bool", "vector2", "vector3", "vector4", "color"]
        case .uv: ["vector2"]
        case .spriteTexture: ["color"]
        case .texture: ["texture2D"]
        case .sampleTexture: ["vector4"]
        default: ["float", "vector2", "vector3", "vector4", "color"]
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if preview.material != nil {
                if preview.selectedModel?.isLoading != true {
                    EditorShaderGraphViewport(model: preview).id("\(preview.material?.program.target.rawValue ?? "")-\(preview.shape)-\(preview.selectedModel?.asset != nil)").frame(
                        height: 190
                    )
                }
                if model.graph?.target == .pbrSurface {
                    EditorEnumField(
                        cases: [L10n.tr("Sphere"), L10n.tr("Plane")] + modelDocuments.map(\.relativePath),
                        selection: Binding(
                            get: { preview.shape == "sphere" ? L10n.tr("Sphere") : preview.shape == "plane" ? L10n.tr("Plane") : preview.shape },
                            set: { value in
                                preview.selectedModel?.cancel()
                                preview.selectedModel = nil
                                if value == L10n.tr("Sphere") {
                                    preview.shape = "sphere"
                                } else if value == L10n.tr("Plane") {
                                    preview.shape = "plane"
                                } else if let document = modelDocuments.first(where: { $0.relativePath == value }) {
                                    preview.shape = value
                                    let selected = EditorModelAssetPreviewModel()
                                    preview.selectedModel = selected
                                    selected.load(document)
                                }
                            }
                        ),
                        accessibilityID: "AdaEditor.ShaderGraph.PreviewShape"
                    )
                }
                HStack {
                    Button(preview.isPlaying ? L10n.text("Pause") : L10n.text("Play")) { preview.isPlaying.toggle() }
                    Button(L10n.text("Restart")) { preview.restart() }
                }
            }
            if preview.isCompiling { Text(L10n.text("Compiling graph…")).foregroundColor(theme.editorColors.muted) }
            if let error = preview.error ?? preview.selectedModel?.error {
                Button {
                    if let id = preview.errorNode { model.selection = [id] }
                } label: {
                    Text(verbatim: error).foregroundColor(.red).lineLimit(4)
                }
            }
            Divider()
        }
    }

    private func addNode() {
        guard let op = ShaderGraph.Operation(rawValue: operation) else {
            return
        }
        let type: ShaderGraph.ValueType
        switch op {
        case .uv: type = .vector2
        case .spriteTexture: type = .color
        case .texture: type = .texture2D
        case .sampleTexture: type = .vector4
        default: type = ShaderGraph.ValueType(rawValue: availableTypes.contains(valueType) ? valueType : availableTypes[0]) ?? .float
        }
        model.addNode(op, type: type, at: (Vector2(140, 100) - canvas.pan) / canvas.zoom)
    }

    private func nodeInspector(_ node: ShaderGraph.Node) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: L10n.tr(EditorShaderGraphModel.operationTitle(node.kind))).font(.system(size: 13, weight: .semibold))
            field("Name", value: node.label ?? "") { value in model.editNode(node.id) { $0.label = value.isEmpty ? nil : value } }
            if node.kind == "parameter" || node.kind == "texture" {
                field(node.kind == "parameter" ? "Parameter ID" : "Texture", value: node.reference ?? "") { value in model.editNode(node.id) { $0.reference = value } }
            }
            if node.kind == "parameter", node.type == .texture2D {
                field("Default Texture", value: node.defaultTexture ?? "") { value in model.editNode(node.id) { $0.defaultTexture = value.isEmpty ? nil : value } }
            }
            ForEach(0..<node.value.count, id: \.self) { index in
                field("Value", value: String(format: "%.5g", node.value[index])) { text in
                    if let value = Float(text), value.isFinite, node.type != .bool || value == 0 || value == 1 { model.editNode(node.id) { $0.value[index] = value } }
                }.accessibilityIdentifier("AdaEditor.ShaderGraph.Value.\(index)")
            }
            ForEach(node.inputs.keys.sorted(), id: \.self) { port in
                HStack {
                    Text(verbatim: L10n.tr(EditorShaderGraphModel.portTitle(port)))
                    Spacer()
                    Button(L10n.text("Disconnect")) { model.editNode(node.id) { $0.inputs[port] = nil } }
                }
            }
            Button(L10n.text("Delete")) { model.removeSelection() }.disabled(node.id == model.graph?.output || model.isReadOnly)
        }.disabled(model.isReadOnly)
    }

    private func outputInspector(_ graph: ShaderGraph) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Output")).font(.system(size: 13, weight: .semibold))
            Text(verbatim: graph.target == .sprite ? "Sprite" : "PBR Surface")
            EditorEnumField(
                cases: ShaderGraph.RenderSettings.Mode.allCases.map { L10n.tr($0.rawValue.capitalized) },
                selection: Binding(
                    get: { L10n.tr(graph.renderSettings.mode.rawValue.capitalized) },
                    set: { title in
                        if let mode = ShaderGraph.RenderSettings.Mode.allCases.first(where: { L10n.tr($0.rawValue.capitalized) == title }) { model.edit { $0.renderSettings.mode = mode } }
                    }
                ),
                accessibilityID: "AdaEditor.ShaderGraph.AlphaMode"
            )
            field("Alpha Cutoff", value: String(graph.renderSettings.alphaCutoff)) { text in
                if let value = Float(text), value.isFinite, (0...1).contains(value) { model.edit { $0.renderSettings.alphaCutoff = value } }
            }
            Toggle(L10n.text("Double Sided"), isOn: Binding(get: { graph.renderSettings.doubleSided }, set: { value in model.edit { $0.renderSettings.doubleSided = value } }))
        }.disabled(model.isReadOnly)
    }

    private func field(_ title: String, value: String, set: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr(title))
            EditorUIDesignerField(placeholder: title, text: Binding(get: { value }, set: set))
        }.drawingGroup()
    }
}
