@_spi(AdaEngine) import AdaEngine

extension EditorShaderGraphEditor {
    var canvasPoint: Vector2 { (Vector2(canvasViewportSize.width / 2, canvasViewportSize.height / 2) - canvas.pan) / canvas.zoom - Vector2(104, 50) }

    var nodeSearch: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(L10n.text("Search Nodes"), text: Binding(get: { search.query }, set: { search.query = $0 })).textFieldStyle(PlainTextFieldStyle()).accessibilityIdentifier(
                    "AdaEditor.ShaderGraph.Search"
                )
                Button(L10n.text("Close")) { search.isPresented = false }
            }
            if let graph = model.graph {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(search.entries(in: graph)) { entry in
                            Button {
                                model.insert(entry, using: search)
                                search.isPresented = false
                            } label: {
                                Text(verbatim: entry.title).frame(maxWidth: .infinity, alignment: .leading)
                            }.accessibilityIdentifier("AdaEditor.ShaderGraph.Search.\(entry.id)")
                        }
                    }
                }.frame(height: 160)
            }
        }.padding(10).font(.system(size: 12)).foregroundColor(theme.editorColors.text).buttonStyle(DefaultButtonStyle()).background(theme.editorColors.surface)
    }

    var parameterPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Parameters")).font(.system(size: 13, weight: .semibold))
                ForEach((model.graph?.nodes ?? []).filter { $0.kind == "parameter" }, id: \.id) { node in
                    Button {
                        model.reveal(node.id, canvas: canvas, size: canvasViewportSize)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: node.label ?? node.reference ?? node.id).lineLimit(2)
                            Text(verbatim: node.type.rawValue).font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
                        }
                    }.accessibilityIdentifier("AdaEditor.ShaderGraph.Parameter.\(node.id)")
                }
                Button(L10n.text("Add Parameter")) {
                    search.open(at: canvasPoint)
                    search.query = L10n.tr("Parameter")
                }
            }.padding(12)
        }.font(.system(size: 12)).foregroundColor(theme.editorColors.text).buttonStyle(DefaultButtonStyle()).background(theme.editorColors.surface)
    }

    @ViewBuilder var graphContextMenu: some View {
        Button(L10n.text("Search Nodes")) { search.open(at: canvasPoint) }
        Button(L10n.text("Copy")) { copyNodes() }
        Button(L10n.text("Paste")) { pasteNodes() }
        Button(L10n.text("Group Selection")) { model.groupSelection() }
        Button(L10n.text("Add Comment")) { model.addComment(at: canvasPoint) }
        Button(L10n.text("Delete")) { model.removeSelection() }
    }

    var organizationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Button(L10n.text("Copy")) { copyNodes() }
                Button(L10n.text("Paste")) { pasteNodes() }
            }
            Button(L10n.text("Copy Graph Source")) { if let graph = model.graph { UIClipboard.setString(EditorShaderGraphTemplates.encode(graph)) } }
            HStack {
                Button(L10n.text("Group Selection")) { model.groupSelection() }
                Button(L10n.text("Add Comment")) { model.addComment(at: canvasPoint) }
            }
            if let graph = model.graph {
                ForEach(graph.groups.keys.sorted(), id: \.self) { id in
                    if let group = graph.groups[id] {
                        field("Group", value: group.title) { value in model.edit(semantic: false) { $0.groups[id]?.title = value } }
                        HStack {
                            Button(L10n.text("Select")) { model.selection = Set(group.nodes) }
                            Button(L10n.text("Remove Group")) { model.edit(semantic: false) { $0.groups[id] = nil } }
                        }
                    }
                }
                ForEach(graph.notes.keys.sorted(), id: \.self) { id in
                    if let note = graph.notes[id] {
                        field("Comment", value: note.text) { value in model.edit(semantic: false) { $0.notes[id]?.text = value } }
                        HStack {
                            field("X", value: String(note.position.x)) { text in
                                if let value = Float(text), value.isFinite { model.edit(semantic: false) { $0.notes[id]?.position.x = value } }
                            }
                            field("Y", value: String(note.position.y)) { text in
                                if let value = Float(text), value.isFinite { model.edit(semantic: false) { $0.notes[id]?.position.y = value } }
                            }
                        }
                        Button(L10n.text("Remove Comment")) { model.edit(semantic: false) { $0.notes[id] = nil } }
                    }
                }
            }
        }.disabled(model.isReadOnly)
    }

    func handleCanvasKey(_ event: KeyEvent) {
        guard event.status == .down else {
            return
        }
        if event.modifiers.contains(.command) {
            switch event.keyCode {
            case .a: model.selection = Set(model.graph?.nodes.map(\.id) ?? [])
            case .c: copyNodes()
            case .v: pasteNodes()
            default: break
            }
        } else {
            switch event.keyCode {
            case .space: search.open(at: canvasPoint)
            case .delete, .backspace: model.removeSelection()
            case .escape:
                search.isPresented = false
                interaction?.abort()
            default: break
            }
        }
    }

    private func copyNodes() { if let text = model.copySelection() { UIClipboard.setString(text) } }
    private func pasteNodes() { if let text = UIClipboard.getString() { model.paste(text, at: canvasPoint) } }
}
