//
//  EditorBottomPanel.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 17.05.2026.
//

import AdaEngine

struct EditorBottomPanel: View {
    @State var viewModel: EditorViewModel
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(metrics.outputTabs, id: \.self) { tab in
                    Text(tab)
                        .font(.system(size: 11))
                        .foregroundColor(tab == viewModel.activeOutputTab ? theme.editorColors.text : theme.editorColors.muted)
                        .padding(.horizontal, metrics.outputTabHorizontalPadding)
                        .frame(height: metrics.outputPanelHeight)
                        .background(tab == viewModel.activeOutputTab ? theme.editorColors.background : Color.clear)
                }
                Spacer()
            }
            .background(theme.editorColors.surface)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(AdaEngineStyleContent.logLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxHeight: .infinity)
        }
        .background {
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        }
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }
}
