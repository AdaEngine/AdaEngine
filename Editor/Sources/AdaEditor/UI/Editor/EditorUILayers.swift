@_spi(AdaEngine) import AdaEngine

extension EditorUISceneModel {
    func toggleLayerCollapsed(_ id: String) {
        if collapsedLayerIDs.remove(id) != nil {
            return
        }
        collapsedLayerIDs.insert(id)
        // Keep selection visible when its containing branch is collapsed.
        document.root.visit { node in
            guard node.id == id else {
                return
            }
            node.visit { child in
                if child.id == selectedID, child.id != id {
                    selectedID = id
                    insertionModifierID = nil
                }
            }
        }
    }
}

extension EditorUISceneEditor {
    struct Row {
        let node: UINodeDescription
        let depth: Int
        let parentID: String?

        var hasChildren: Bool {
            !node.children.isEmpty || node.modifiers.contains { !$0.children.isEmpty }
        }
    }

    var layerCount: Int {
        var count = 0
        model.document.root.visit { _ in count += 1 }
        return count
    }

    var rows: [Row] {
        func flatten(_ node: UINodeDescription, depth: Int, parentID: String?) -> [Row] {
            let row = Row(node: node, depth: depth, parentID: parentID)
            guard !model.collapsedLayerIDs.contains(node.id) else {
                return [row]
            }
            return [row]
                + node.children.flatMap { flatten($0, depth: depth + 1, parentID: node.id) }
                + node.modifiers.flatMap { $0.children.flatMap { flatten($0, depth: depth + 1, parentID: node.id) } }
        }
        return flatten(model.document.root, depth: 0, parentID: nil)
    }

    func layerRow(_ row: Row) -> some View {
        HStack(spacing: 0) {
            if row.hasChildren {
                Button {
                    model.toggleLayerCollapsed(row.node.id)
                } label: {
                    symbol(model.collapsedLayerIDs.contains(row.node.id) ? "\u{E5CC}" : "\u{E5CF}", size: 14)
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.UIScene.Layer.Collapse.\(row.node.id)")
            } else {
                Color.clear.frame(width: 20, height: 26)
            }
            layerSelectionButton(row)
        }
        .padding(.leading, Float(min(row.depth, 8) * 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func layerSelectionButton(_ row: Row) -> some View {
        Button {
            model.selectedID = row.node.id
            model.insertionModifierID = nil
        } label: {
            HStack(spacing: 7) {
                symbol(EditorUIDesignerSymbols.icon(row.node.type), size: 14)
                Text(row.node.type).lineLimit(1)
                Spacer()
                if row.depth == 0 {
                    Text(L10n.text("ROOT")).font(.system(size: 9, weight: .semibold)).foregroundColor(theme.editorColors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(EditorUIDesignerButtonStyle(colors: theme.editorColors, selected: model.selectedID == row.node.id))
        .accessibilityIdentifier("AdaEditor.UIScene.Node.\(row.node.id)")
        .gesture(designerDragGesture(.node(row.node.id)))
        .background(model.designerDrag.targetLayerID == row.node.id ? (model.designerDrag.layerDropIsValid ? theme.editorColors.blue : .red).opacity(0.2) : .clear)
        .overlay {
            if model.designerDrag.targetLayerID == row.node.id, let after = model.designerDrag.layerInsertionAfter {
                RectangleShape().fill(model.designerDrag.layerDropIsValid ? theme.editorColors.blue : .red)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: after ? .bottom : .top)
                    .allowsHitTesting(false)
            }
            GeometryReader { geometry in
                Color.clear
                    .onAppear { model.designerDrag.layerFrames[row.node.id] = { geometry.frame(in: .global) } }
                    .onDisappear { model.designerDrag.layerFrames.removeValue(forKey: row.node.id) }
            }
            .allowsHitTesting(false)
        }
        .contextMenu {
            Button(L10n.text("Move selected here")) { model.move(model.selectedID, into: row.node.id) }
            if row.hasChildren {
                Button(model.collapsedLayerIDs.contains(row.node.id) ? L10n.text("Expand") : L10n.text("Collapse")) {
                    model.toggleLayerCollapsed(row.node.id)
                }
            }
            Button(L10n.text("Duplicate")) {
                model.selectedID = row.node.id
                model.duplicateSelected()
            }
            Button(L10n.text("Delete")) {
                model.selectedID = row.node.id
                model.removeSelected()
            }
        }
    }
}
