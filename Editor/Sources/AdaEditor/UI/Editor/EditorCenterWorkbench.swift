@_spi(AdaEngine) import AdaEngine

struct EditorCenterWorkbench: View {
    let viewModel: EditorWorkbenchViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            editorTabs
                .frame(height: AdaEngineStyleLayoutSpec.editorTabHeight)
            viewport(metrics: metrics)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(100)
                .overlay(anchor: .bottomTrailing) {
                    aiFlightBox(metrics: metrics)
                        .padding(metrics.size.height < 520 ? 8 : 18)
                }
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }
}

extension EditorCenterWorkbench {
    private var editorTabs: some View {
        HStack(spacing: 0) {
            ForEach(AdaEngineStyleContent.editorTabs, id: \.self) { tab in
                editorTab(tab, active: tab == viewModel.activeEditorTab)
            }
            Spacer()
        }
    }
    
    private func editorTab(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
            .padding(.horizontal, 16)
            .frame(height: AdaEngineStyleLayoutSpec.editorTabHeight)
            .background(active ? theme.editorColors.background : Color.clear)
            .overlay {
                VStack(spacing: 0) {
                    Spacer()
                    if active {
                        RectangleShape()
                            .fill(theme.editorColors.blue)
                            .frame(height: 2)
                    }
                }
            }
    }
    
    private func viewport(metrics: AdaEngineStyleLayoutMetrics) -> some View {
        ZStack {
            Color.red.opacity(0.2)
        }
    }
    
    private func aiFlightBox(metrics: AdaEngineStyleLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if metrics.showsAIHeader {
                HStack {
                    Text("▲  \(AdaEngineStyleContent.aiTitle.uppercased())")
                        .font(.system(size: 12))
                        .foregroundColor(theme.editorColors.purple)
                    Spacer()
                    Text(AdaEngineStyleContent.aiHint)
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.muted)
                }
            }
            TextField(AdaEngineStyleContent.aiPlaceholder, text: viewModel.aiPromptBinding)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.background))
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityIdentifier("AdaEditor.AIFlightBox.Input")
            
            if metrics.showsAIChips {
                HStack(spacing: 8) {
                    ForEach(metrics.visibleAIChips, id: \.self) { chip in
                        aiChip(chip)
                    }
                    Spacer()
                    Button(action: {}) {
                        Text("›")
                    }
                    .font(.system(size: 18))
                    .foregroundColor(theme.editorColors.purple)
                    .frame(width: 30, height: 28)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangleShape(cornerRadius: 16).fill(theme.editorColors.surface.opacity(0.96)))
        .frame(maxWidth: 350)
        .accessibilityIdentifier("AdaEditor.AIFlightBox")
    }
    
    private func aiChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10))
            .foregroundColor(viewModel.hoveredChip == title ? theme.editorColors.text : theme.editorColors.purple)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(RoundedRectangleShape(cornerRadius: 13).fill(viewModel.hoveredChip == title ? theme.editorColors.purple.opacity(0.24) : theme.editorColors.purple.opacity(0.10)))
            .overlay { RoundedRectangleShape(cornerRadius: 13).stroke(theme.editorColors.purple.opacity(0.35), lineWidth: 1) }
            .onHover { viewModel.hoveredChip = $0 ? title : nil }
    }
}
