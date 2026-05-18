@_spi(AdaEngine) import AdaEngine

struct EditorRightToolStrip: View {
    let viewModel: EditorToolStripViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 7) {
            adaEditorStripButton(
                "AI",
                icon: "△",
                active: viewModel.activeRightTool == "AI",
                hoveredTool: viewModel.hoveredTool,
                setHoveredTool: { viewModel.hoveredTool = $0 },
                theme: theme,
                accent: theme.editorColors.purple
            )
            Spacer()
            adaEditorStripButton(
                "Settings",
                icon: "⚙",
                active: viewModel.activeRightTool == "Settings",
                hoveredTool: viewModel.hoveredTool,
                setHoveredTool: { viewModel.hoveredTool = $0 },
                theme: theme
            )
        }
        .padding(.vertical, 10)
        .background(theme.editorColors.background)
    }
}

struct EditorLeftToolStrip: View {
    @State var viewModel: EditorToolStripViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 7) {
            adaEditorStripButton(
                "Project",
                icon: "▣",
                active: viewModel.activeLeftTool == "Project",
                hoveredTool: viewModel.hoveredTool,
                setHoveredTool: { viewModel.hoveredTool = $0 },
                theme: theme
            )
            adaEditorStripButton(
                "Add",
                icon: "+",
                active: viewModel.activeLeftTool == "Add",
                hoveredTool: viewModel.hoveredTool,
                setHoveredTool: { viewModel.hoveredTool = $0 },
                theme: theme
            )
            adaEditorStripButton(
                "Git",
                icon: "⎇",
                active: viewModel.activeLeftTool == "Git",
                hoveredTool: viewModel.hoveredTool,
                setHoveredTool: { viewModel.hoveredTool = $0 },
                theme: theme
            )
            Spacer()
        }
        .padding(.vertical, 10)
        .background(theme.editorColors.background)
    }
}
