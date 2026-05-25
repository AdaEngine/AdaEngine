@_spi(AdaEngine) import AdaEngine

struct EditorProjectSidebar: View {
    let viewModel: EditorProjectSidebarViewModel
    let onOpenItem: (EditorProjectSidebarViewModel.Item) -> Void
    let onOpenRawItem: (EditorProjectSidebarViewModel.Item) -> Void
    let onImportAssets: () -> Void
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PROJECT").font(.system(size: 12)).foregroundColor(theme.editorColors.muted)
                Spacer()
                Button(action: onImportAssets) {
                    Text("+")
                        .font(.system(size: 14))
                        .foregroundColor(theme.editorColors.blue)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.ProjectTree.ImportAssets")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.visibleItems, id: \.id) { item in
                        projectTreeRow(item)
                    }
                }
                .padding(8)
            }
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private func projectTreeRow(_ item: EditorProjectSidebarViewModel.Item) -> some View {
        Button(action: { onOpenItem(item) }) {
            HStack(spacing: 6) {
                Text(disclosureIcon(for: item))
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .frame(width: 14)
                Text(fileIcon(for: item))
                    .font(.system(size: 12))
                    .foregroundColor(iconColor(for: item))
                    .frame(width: 16)
                Text(item.title)
                Spacer()
            }
            .font(.system(size: 12))
            .foregroundColor(item.isActive ? theme.editorColors.text : theme.editorColors.muted)
            .padding(.leading, 6 + Float(item.level) * 16)
            .padding(.trailing, 6)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(item.isActive ? theme.editorColors.blue.opacity(0.22) : Color.clear))
        }
        .buttonStyle(DefaultButtonStyle())
        .contextMenu {
            if item.kind == .scene {
                Button("Open as Raw") {
                    onOpenRawItem(item)
                }
            }
        }
        .accessibilityIdentifier("AdaEditor.ProjectTree.\(item.title)")
    }

    private func disclosureIcon(for item: EditorProjectSidebarViewModel.Item) -> String {
        guard item.isFolder else {
            return ""
        }

        return viewModel.isCollapsed(item) ? ">" : "v"
    }

    private func fileIcon(for item: EditorProjectSidebarViewModel.Item) -> String {
        switch item.kind {
        case .folder:
            return viewModel.isCollapsed(item) ? "+" : "-"
        case .scene:
            return "#"
        case .text(let language):
            return textFileIcon(for: language)
        case .image:
            return "□"
        case .audio:
            return "~"
        case .genericAsset:
            return "*"
        case .unsupported:
            return "?"
        }
    }

    private func textFileIcon(for language: EditorSourceLanguage) -> String {
        switch language {
        case .json, .yaml:
            return "{}"
        case .markdown, .plainText:
            return "="
        case .packageManifest, .swift, .ada, .c, .cpp, .glsl, .metal:
            return "<>"
        }
    }

    private func iconColor(for item: EditorProjectSidebarViewModel.Item) -> Color {
        switch item.kind {
        case .scene:
            return theme.editorColors.purple
        case .text:
            return theme.editorColors.blue
        case .image:
            return theme.editorColors.blue
        case .audio:
            return theme.editorColors.purple
        case .genericAsset:
            return theme.editorColors.text.opacity(0.72)
        case .folder, .unsupported:
            return theme.editorColors.muted
        }
    }
}
