@_spi(AdaEngine) import AdaEngine

enum EditorProjectTreeIcon {
    static let chevronRight = "\u{E5CC}"
    static let expandMore = "\u{E5CF}"
    static let folder = "\u{E2C7}"
    static let folderOpen = "\u{E2C8}"
    static let description = "\u{E873}"
    static let code = "\u{E86F}"
    static let article = "\u{EF42}"
    static let image = "\u{E3F4}"
    static let audioFile = "\u{EB82}"
    static let scene = "\u{F720}"

    static let allSymbols = [
        chevronRight,
        expandMore,
        folder,
        folderOpen,
        description,
        code,
        article,
        image,
        audioFile,
        scene,
    ]
}

struct EditorProjectSidebar: View {
    let viewModel: EditorProjectSidebarViewModel
    let projectRootItem: EditorProjectSidebarViewModel.Item?
    let onOpenItem: (EditorProjectSidebarViewModel.Item) -> Void
    let onOpenRawItem: (EditorProjectSidebarViewModel.Item) -> Void
    let onNewFile: () -> Void
    let onImportAssets: () -> Void
    let onRevealItem: (EditorProjectSidebarViewModel.Item) -> Void
    let onOpenInDefaultApplication: (EditorProjectSidebarViewModel.Item) -> Void
    let onOpenInTerminal: (EditorProjectSidebarViewModel.Item) -> Void
    let onFindInFolder: (EditorProjectSidebarViewModel.Item) -> Void
    let onFindInProjectRoot: () -> Void
    let onCopyPath: (EditorProjectSidebarViewModel.Item, Bool) -> Void
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PROJECT")
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.muted)
                    .frame(width: 120, alignment: .leading)
                Spacer()
                Button(action: onNewFile) {
                    HStack(spacing: 5) {
                        Text("+")
                            .font(.system(size: 14))
                        Text("New File")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.editorColors.blue)
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.ProjectTree.NewFile")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            GeometryReader { geometry in
                ZStack(anchor: .topLeading) {
                    projectTreeBackground(width: geometry.size.width, height: geometry.size.height)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(viewModel.visibleItems, id: \.id) { item in
                                projectTreeRow(item)
                            }
                        }
                        .frame(width: max(0, geometry.size.width - 16), alignment: .leading)
                        .padding(8)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                }
            }
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private func projectTreeBackground(width: Float, height: Float) -> some View {
        Color.clear
            .frame(width: width, height: height)
            .contextMenu {
                Button("New File") {
                    onNewFile()
                }
                Button("Import Assets") {
                    onImportAssets()
                }
                if let projectRootItem {
                    Button("Reveal in Finder") {
                        onRevealItem(projectRootItem)
                    }
                    Button("Open in Terminal") {
                        onOpenInTerminal(projectRootItem)
                    }
                    Button("Find in Folder...") {
                        onFindInProjectRoot()
                    }
                    Button("Copy Path") {
                        onCopyPath(projectRootItem, false)
                    }
                }
                Button("Expand All") {
                    viewModel.expandAll()
                }
                Button("Collapse All") {
                    viewModel.collapseAll()
                }
            }
            .accessibilityIdentifier("AdaEditor.ProjectTree.Background")
    }

    private func projectTreeRow(_ item: EditorProjectSidebarViewModel.Item) -> some View {
        Button(action: { onOpenItem(item) }) {
            HStack(spacing: 6) {
                Text(disclosureIcon(for: item))
                    .font(AdaEditorMaterialSymbolFont.font(size: 16))
                    .foregroundColor(theme.editorColors.muted)
                    .frame(width: 16, height: 18)
                Text(fileIcon(for: item))
                    .font(AdaEditorMaterialSymbolFont.font(size: 17))
                    .foregroundColor(iconColor(for: item))
                    .frame(width: 18, height: 18)
                Text(item.title)
                    .font(.system(size: 12, weight: .bold))
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
        .contextMenu(onPresent: { viewModel.select(item) }) {
            Button("New File") {
                onNewFile()
            }
            Button(item.isFolder ? (viewModel.isCollapsed(item) ? "Expand" : "Collapse") : "Open") {
                onOpenItem(item)
            }
            if item.kind == .scene {
                Button("Open as Raw") {
                    onOpenRawItem(item)
                }
            }
            Button("Reveal in Finder") {
                onRevealItem(item)
            }
            if !item.isFolder {
                Button("Open in Default App") {
                    onOpenInDefaultApplication(item)
                }
            }
            Button("Open in Terminal") {
                onOpenInTerminal(item)
            }
            Button("Find in Folder...") {
                onFindInFolder(item)
            }
            Button("Copy Path") {
                onCopyPath(item, false)
            }
            Button("Copy Relative Path") {
                onCopyPath(item, true)
            }
            if item.isFolder {
                Button("Expand All") {
                    viewModel.expandAll()
                }
                Button("Collapse All") {
                    viewModel.collapseAll()
                }
            }
        }
        .accessibilityIdentifier("AdaEditor.ProjectTree.\(item.title)")
    }

    private func disclosureIcon(for item: EditorProjectSidebarViewModel.Item) -> String {
        guard item.isFolder else {
            return ""
        }

        return viewModel.isCollapsed(item) ? EditorProjectTreeIcon.chevronRight : EditorProjectTreeIcon.expandMore
    }

    private func fileIcon(for item: EditorProjectSidebarViewModel.Item) -> String {
        switch item.kind {
        case .folder:
            return viewModel.isCollapsed(item) ? EditorProjectTreeIcon.folder : EditorProjectTreeIcon.folderOpen
        case .scene:
            return EditorProjectTreeIcon.scene
        case .text(let language):
            return textFileIcon(for: language)
        case .image:
            return EditorProjectTreeIcon.image
        case .audio:
            return EditorProjectTreeIcon.audioFile
        case .genericAsset:
            return EditorProjectTreeIcon.description
        case .unsupported:
            return EditorProjectTreeIcon.description
        }
    }

    private func textFileIcon(for language: EditorSourceLanguage) -> String {
        switch language {
        case .json, .yaml:
            return EditorProjectTreeIcon.code
        case .markdown, .plainText:
            return EditorProjectTreeIcon.article
        case .packageManifest, .swift, .ada, .c, .cpp, .glsl, .metal:
            return EditorProjectTreeIcon.code
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
