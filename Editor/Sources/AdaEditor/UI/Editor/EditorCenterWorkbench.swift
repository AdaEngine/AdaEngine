@_spi(AdaEngine) import AdaEngine

struct EditorCenterWorkbench: View {
    let viewModel: EditorWorkbenchViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            editorTabs
                .frame(height: AdaEngineStyleLayoutSpec.editorTabHeight)
            activeDocumentView(metrics: metrics)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(100)
                .overlay(anchor: .bottomTrailing) {
                    if showsSceneControls {
                        aiFlightBox(metrics: metrics)
                            .padding(metrics.size.height < 520 ? 8 : 18)
                    }
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
            ForEach(viewModel.openDocuments, id: \.id) { document in
                editorTab(document, active: document.id == viewModel.activeDocumentID)
            }
            Spacer()
        }
    }
    
    private func editorTab(_ document: EditorWorkbenchDocument, active: Bool) -> some View {
        Button(action: { viewModel.selectDocument(id: document.id) }) {
            Text(document.title)
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
        .buttonStyle(DefaultButtonStyle())
    }

    @ViewBuilder
    private func activeDocumentView(metrics: AdaEngineStyleLayoutMetrics) -> some View {
        switch viewModel.activeDocument {
        case .scene(let document):
            sceneDocumentEditor(document: document)
        case .text(let document):
            EditorCodeFileView(
                document: document,
                text: viewModel.textDocumentBinding(documentID: document.id),
                fontSize: viewModel.codeFontSize
            )
        case nil:
            emptyWorkbench
        }
    }

    private var showsSceneControls: Bool {
        false
    }

    private var emptyWorkbench: some View {
        ZStack {
            theme.editorColors.background
            Text("No file selected")
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sceneDocumentEditor(document: EditorSceneDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sceneDocumentHeader(document: document)

            if let errorMessage = document.errorMessage {
                sceneDocumentError(message: errorMessage)
            } else {
                sceneDocumentTextEditor(document: document)
            }
        }
        .background(theme.editorColors.background)
        .accessibilityIdentifier("AdaEditor.SceneDocument.\(document.title)")
    }

    private func sceneDocumentHeader(document: EditorSceneDocument) -> some View {
        HStack(spacing: 8) {
            Text(document.title)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            Text(document.relativePath)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
            if let status = document.statusMessage {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(document.isDirty ? theme.editorColors.purple : theme.editorColors.muted)
            }
            Button(action: { viewModel.appendSceneLine(documentID: document.id) }) {
                Text("+")
                    .font(.system(size: 14))
                    .foregroundColor(theme.editorColors.text)
                    .frame(width: 26, height: 22)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surfaceElevated))
            }
            .buttonStyle(DefaultButtonStyle())
            Button(action: { viewModel.saveSceneDocument(id: document.id) }) {
                Text(document.isDirty ? "Save *" : "Save")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.blue)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
            }
            .buttonStyle(DefaultButtonStyle())
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(theme.editorColors.surface)
    }

    private func sceneDocumentTextEditor(document: EditorSceneDocument) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.sceneLines(for: document).indices), id: \.self) { index in
                    sceneDocumentLine(document: document, lineIndex: index)
                }
            }
            .padding(.vertical, 10)
            .padding(.trailing, 28)
            .fixedSize(horizontal: true, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sceneDocumentLine(document: EditorSceneDocument, lineIndex: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(lineIndex + 1))
                .font(AdaEditorCodeFont.font(size: viewModel.codeFontSize - 1))
                .foregroundColor(viewModel.codeColorPalette.lineNumber)
                .frame(width: 46, alignment: .trailing)
            TextField("", text: viewModel.sceneLineBinding(documentID: document.id, lineIndex: lineIndex))
                .font(AdaEditorCodeFont.font(size: viewModel.codeFontSize))
                .foregroundColor(theme.editorColors.text)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 820, height: max(22, Float(viewModel.codeFontSize * 1.8)), alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(height: max(24, Float(viewModel.codeFontSize * 2)))
        .background(lineIndex == 0 ? viewModel.codeColorPalette.currentLineBackground.opacity(0.55) : Color.clear)
    }

    private func sceneDocumentError(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unable to open scene")
                .font(.system(size: 13))
                .foregroundColor(theme.editorColors.text)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func viewportGrid(size: Size, metrics: AdaEngineStyleLayoutMetrics) -> some View {
        ZStack {
            VStack(spacing: metrics.gridRowSpacing(for: size)) {
                ForEach(0..<14) { index in
                    RectangleShape()
                        .fill(index == 7 ? theme.editorColors.blue.opacity(0.20) : theme.editorColors.border.opacity(0.32))
                        .frame(height: index == 7 ? 2 : 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, metrics.gridHorizontalPadding(for: size))
            .padding(.vertical, metrics.gridBottomPadding(for: size))

            HStack(spacing: metrics.gridColumnSpacing(for: size)) {
                ForEach(0..<18) { index in
                    RectangleShape()
                        .fill(index == 9 ? theme.editorColors.purple.opacity(0.18) : theme.editorColors.border.opacity(0.28))
                        .frame(width: index == 9 ? 2 : 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, metrics.gridHorizontalPadding(for: size))
            .padding(.vertical, metrics.gridBottomPadding(for: size))
        }
    }

    private func viewportGizmo(size: Size, metrics: AdaEngineStyleLayoutMetrics) -> some View {
        let scale = metrics.gizmoScale(for: size)

        return VStack {
            Spacer(minLength: metrics.gizmoTopPadding(for: size))
            HStack {
                Spacer()
                ZStack {
                    CircleShape()
                        .fill(theme.editorColors.blue.opacity(0.16))
                        .frame(width: 86 * scale, height: 86 * scale)
                    RectangleShape()
                        .fill(theme.editorColors.blue.opacity(0.72))
                        .frame(width: 72 * scale, height: 2)
                    RectangleShape()
                        .fill(theme.editorColors.purple.opacity(0.70))
                        .frame(width: 2, height: 72 * scale)
                    CircleShape()
                        .fill(theme.editorColors.text.opacity(0.82))
                        .frame(width: 8 * scale, height: 8 * scale)
                }
                Spacer()
            }
            Spacer()
        }
    }

    private func viewportStatus(document: EditorSceneDocument) -> some View {
        VStack {
            HStack {
                Text("Scene · \(document.relativePath)")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface.opacity(0.88)))
                Spacer()
            }
            Spacer()
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
