@_spi(AdaEngine) import AdaEngine

struct EditorRightToolStrip: View {
    let viewModel: EditorToolStripViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 7) {
            ForEach(viewModel.rightTools, id: \.identifier) { item in
                adaEditorStripButton(
                    item,
                    active: viewModel.activeRightTool == item.identifier,
                    theme: theme,
                    accent: item.identifier == "swiftPackageTasks" ? theme.editorColors.purple : nil,
                    action: {
                        viewModel.selectRightTool(item)
                    }
                )
            }
            Spacer()
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
            ForEach(viewModel.leftTopTools, id: \.identifier) { item in
                adaEditorStripButton(
                    item,
                    active: viewModel.activeLeftTool == item.identifier,
                    theme: theme,
                    action: {
                        viewModel.selectLeftTool(item)
                    }
                )
            }
            Spacer()
            ForEach(viewModel.leftBottomTools, id: \.identifier) { item in
                adaEditorStripButton(
                    item,
                    active: viewModel.activeLeftTool == item.identifier,
                    theme: theme,
                    action: {
                        viewModel.selectLeftTool(item)
                    }
                )
            }
        }
        .padding(.vertical, 10)
        .background(theme.editorColors.background)
    }
}
