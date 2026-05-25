@_spi(AdaEngine) import AdaEngine

struct EditorSceneHierarchySidebar: View {
    let document: EditorSceneDocument?
    let onSelectEntity: (String) -> Void
    let onToggleEntityExpanded: (String) -> Void

    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle("HIERARCHY", trailing: trailingTitle, theme: theme)

            if let document, let sceneModel = document.sceneModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(EditorSceneHierarchyModel.visibleItems(for: sceneModel), id: \.id) { item in
                            hierarchyRow(item)
                        }
                    }
                    .padding(8)
                }
            } else {
                emptyState
            }
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private var trailingTitle: String {
        guard let document, let sceneModel = document.sceneModel else {
            return ""
        }

        return "\(sceneModel.entities.count) entities"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No scene selected")
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            Text("Open a scene file to inspect its entities.")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hierarchyRow(_ item: EditorSceneHierarchyItem) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: {
                if item.hasChildren {
                    onToggleEntityExpanded(item.id)
                }
            }) {
                Text(disclosureIcon(for: item))
                    .font(.system(size: 11))
                    .foregroundColor(item.hasChildren ? theme.editorColors.muted : Color.clear)
                    .frame(width: 14, height: 26)
            }
            .buttonStyle(DefaultButtonStyle())

            Button(action: { onSelectEntity(item.id) }) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.isEnabled ? "●" : "○")
                            .font(.system(size: 9))
                            .foregroundColor(item.isEnabled ? theme.editorColors.blue : theme.editorColors.muted)
                            .frame(width: 12)
                        Text(item.name)
                            .font(.system(size: 12))
                            .foregroundColor(item.isSelected ? theme.editorColors.text : theme.editorColors.muted)
                            .lineLimit(1)
                        Spacer()
                    }

                    Text(componentSummary(for: item))
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.muted.opacity(0.92))
                        .lineLimit(1)

                    if let resourceSummary = resourceSummary(for: item) {
                        Text(resourceSummary)
                            .font(.system(size: 10))
                            .foregroundColor(theme.editorColors.purple.opacity(0.90))
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(DefaultButtonStyle())
        }
        .padding(.leading, 4 + Float(item.level) * 16)
        .background(RoundedRectangleShape(cornerRadius: 5).fill(item.isSelected ? theme.editorColors.blue.opacity(0.22) : Color.clear))
        .accessibilityIdentifier("AdaEditor.SceneHierarchy.\(item.name)")
    }

    private func disclosureIcon(for item: EditorSceneHierarchyItem) -> String {
        guard item.hasChildren else {
            return ""
        }

        return item.isExpanded ? "v" : ">"
    }

    private func componentSummary(for item: EditorSceneHierarchyItem) -> String {
        guard !item.componentNames.isEmpty else {
            return "No components"
        }

        let visibleComponents = item.componentNames.prefix(3).joined(separator: ", ")
        let remainingCount = item.componentNames.count - 3
        if remainingCount > 0 {
            return "\(visibleComponents) +\(remainingCount)"
        }

        return visibleComponents
    }

    private func resourceSummary(for item: EditorSceneHierarchyItem) -> String? {
        guard let resource = item.resources.first else {
            return nil
        }

        let suffix = item.resources.count > 1 ? " +\(item.resources.count - 1)" : ""
        return "\(resource.fieldName): \(resource.value)\(suffix)"
    }
}
