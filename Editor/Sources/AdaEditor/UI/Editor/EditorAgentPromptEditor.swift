@_spi(AdaEngine) import AdaEngine

/// Own the resize state beside the text field so the transcript does not rebuild on drag.
struct EditorAgentPromptEditor: View {
    let viewModel: EditorAgentViewModel
    @State private var composerHeight: Float = 104
    @State private var composerDragStart: Float?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangleShape(cornerRadius: 2)
                    .fill(theme.editorColors.muted.opacity(0.6))
                    .frame(width: 28, height: 3)
                EditorResizeHandle(axis: .vertical) { translation in
                    let start = composerDragStart ?? composerHeight
                    composerDragStart = start
                    composerHeight = min(320, max(64, start - translation.height))
                } onResizeEnded: {
                    composerDragStart = nil
                }
            }
            .frame(height: 10)
            .accessibilityIdentifier("AdaEditor.Agent.ResizeComposer")

            TextEditor(
                "Ask the agent. Use / for commands, @ for context.",
                text: viewModel.promptBinding,
                sourceInteraction: TextEditorSourceInteraction(
                    focusedRange: viewModel.promptCompletionFocus,
                    onCaretChange: viewModel.updatePromptCaret,
                    onRequestCompletion: { _, _ in viewModel.dismissCompletions() },
                    onMoveCompletionSelection: viewModel.moveCompletionSelection,
                    onAcceptCompletion: viewModel.submitPromptFromKeyboard
                ),
                showsLineNumbers: false
            )
            .font(.system(size: 14))
            .foregroundColor(theme.editorColors.text)
            .frame(height: composerHeight)
            .frame(minWidth: 0, maxWidth: .infinity)
            .textEditorColors(composerTextEditorColors)
            .accessibilityIdentifier("AdaEditor.Agent.Prompt")
        }
    }

    private var composerTextEditorColors: TextEditorColors {
        TextEditorColors(
            background: theme.editorColors.surface,
            border: Color.clear,
            focusedBorder: Color.clear,
            gutter: Color.clear,
            gutterRule: Color.clear,
            currentLineBackground: Color.clear,
            selection: theme.editorColors.blue.opacity(0.24)
        )
    }
}
