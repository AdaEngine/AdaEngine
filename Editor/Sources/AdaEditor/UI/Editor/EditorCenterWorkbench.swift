@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorCenterWorkbench: View {
    let viewModel: EditorWorkbenchViewModel
    let inspectorViewModel: EditorInspectorSidebarViewModel
    let playModeState: EditorPlayModeState
    let onSourceHover: ((EditorTextDocument, EditorSourceLocation?) -> Void)?
    let onGoToDefinition: ((EditorTextDocument, EditorSourceLocation) -> Void)?
    let sourceContextMenuItems: ((EditorTextDocument, EditorSourceLocation) -> [TextEditorContextMenuItem])?
    let onSelectDocument: ((String) -> Void)?
    let onSelectPreview: ((EditorPreviewDeclaration) -> Void)?
    let onRebuildPreview: (() -> Void)?
    let onShowPreviewBuildOutput: (() -> Void)?
    
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
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(viewModel.openDocuments, id: \.id) { document in
                    editorTab(document, active: document.id == viewModel.activeDocumentID)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(theme.editorColors.surfaceElevated)
    }
    
    private func editorTab(_ document: EditorWorkbenchDocument, active: Bool) -> some View {
        HStack(spacing: 8) {
            Button(action: { onSelectDocument?(document.id) ?? viewModel.selectDocument(id: document.id) }) {
                HStack(spacing: 7) {
                    Text(tabIcon(for: document))
                        .font(.system(size: 12))
                        .foregroundColor(tabIconColor(for: document))
                    Text(tabTitle(for: document))
                        .font(.system(size: 12))
                        .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
                        .lineLimit(1)
                }
                .padding(.leading, 10)
                .frame(height: 26)
            }
            .buttonStyle(DefaultButtonStyle())

            Button(action: { viewModel.closeDocument(id: document.id) }) {
                Text("×")
                    .font(.system(size: 12))
                    .foregroundColor(active ? theme.editorColors.text.opacity(0.75) : theme.editorColors.muted.opacity(0.70))
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangleShape(cornerRadius: 4).fill(active ? theme.editorColors.surface.opacity(0.62) : Color.clear))
            }
            .buttonStyle(DefaultButtonStyle())
            .padding(.trailing, 8)
        }
        .frame(height: 26)
        .background(RoundedRectangleShape(cornerRadius: 5).fill(active ? theme.editorColors.surface : theme.editorColors.surfaceElevated))
        .overlay {
            RoundedRectangleShape(cornerRadius: 5)
                .stroke(active ? theme.editorColors.blue.opacity(0.72) : theme.editorColors.border.opacity(0.52), lineWidth: 1)
        }
        .overlay(anchor: .top) {
            if active {
                RectangleShape()
                    .fill(theme.editorColors.blue)
                    .frame(height: 2)
            }
        }
        .accessibilityIdentifier("AdaEditor.Tab.\(document.title)")
    }

    private func tabIcon(for document: EditorWorkbenchDocument) -> String {
        switch document {
        case .scene:
            return "#"
        case .text(let document):
            return document.language == .swift ? "<>" : "{}"
        case .asset(let document):
            switch document.kind {
            case .image:
                return "□"
            case .audio:
                return "~"
            case .generic:
                return "*"
            }
        }
    }

    private func tabTitle(for document: EditorWorkbenchDocument) -> String {
        document.isDirty ? "\(document.title) *" : document.title
    }

    private func tabIconColor(for document: EditorWorkbenchDocument) -> Color {
        switch document {
        case .scene:
            return theme.editorColors.purple
        case .text:
            return theme.editorColors.blue
        case .asset(let document):
            switch document.kind {
            case .image:
                return theme.editorColors.blue
            case .audio:
                return theme.editorColors.purple
            case .generic:
                return theme.editorColors.muted
            }
        }
    }

    @ViewBuilder
    private func activeDocumentView(metrics: AdaEngineStyleLayoutMetrics) -> some View {
        switch viewModel.activeDocument {
        case .scene(let document):
            sceneDocumentEditor(document: document)
        case .text(let document):
            textDocumentEditor(document: document)
        case .asset(let document):
            assetPreview(document: document)
        case nil:
            emptyWorkbench
        }
    }

    @ViewBuilder
    private func assetPreview(document: EditorAssetDocument) -> some View {
        switch document.kind {
        case .image:
            imageAssetPreview(document: document)
        case .audio, .generic:
            assetMetadataPreview(document: document)
        }
    }

    private func imageAssetPreview(document: EditorAssetDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            assetPreviewHeader(document: document)
            ZStack {
                theme.editorColors.background
                if let path = document.absolutePath, let image = try? Image(contentsOf: URL(fileURLWithPath: path, isDirectory: false)) {
                    image
                        .resizable()
                        .aspectRatio(Float(image.width) / Float(max(1, image.height)), contentMode: .fit)
                        .padding(20)
                } else {
                    assetPreviewError(document.errorMessage ?? "Unable to load image preview.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .background(theme.editorColors.background)
    }

    private func assetMetadataPreview(document: EditorAssetDocument) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            assetPreviewHeader(document: document)
            VStack(alignment: .leading, spacing: 10) {
                assetMetadataRow("Kind", document.kind == .audio ? "Audio" : "Asset")
                assetMetadataRow("Path", document.relativePath)
                if let assetReference = document.assetReference {
                    assetMetadataRow("Reference", assetReference)
                }
                assetMetadataRow("Extension", document.fileExtension.isEmpty ? "none" : document.fileExtension)
                if let byteCount = document.byteCount {
                    assetMetadataRow("Size", ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file))
                }
                if let modifiedAt = document.modifiedAt {
                    assetMetadataRow("Modified", modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let errorMessage = document.errorMessage {
                    assetMetadataRow("Preview", errorMessage)
                }
            }
            .padding(14)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface))
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.editorColors.background)
    }

    private func assetPreviewHeader(document: EditorAssetDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.title)
                .font(.system(size: 15))
                .foregroundColor(theme.editorColors.text)
            Text(document.assetReference ?? document.relativePath)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
        }
    }

    private func assetMetadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .lineLimit(3)
            Spacer()
        }
    }

    private func assetPreviewError(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundColor(theme.editorColors.muted)
    }

    @ViewBuilder
    private func textDocumentEditor(document: EditorTextDocument) -> some View {
        switch viewModel.previewStatus {
        case .hidden:
            codeFileView(document: document)
        default:
            HStack(spacing: 0) {
                codeFileView(document: document)
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(100)

                Divider()
                    .frame(width: 1)

                EditorPreviewPanel(
                    status: viewModel.previewStatus,
                    selectedPreviewID: viewModel.selectedPreviewID,
                    onSelectPreview: { declaration in
                        onSelectPreview?(declaration)
                    },
                    onRebuild: {
                        onRebuildPreview?()
                    },
                    onShowBuildOutput: {
                        onShowPreviewBuildOutput?()
                    }
                )
                .frame(minWidth: 360, maxWidth: 360, maxHeight: .infinity)
            }
        }
    }

    private func codeFileView(document: EditorTextDocument) -> some View {
        EditorCodeFileView(
            document: document,
            text: viewModel.textDocumentBinding(documentID: document.id),
            fontSize: viewModel.codeFontSize,
            colorPalette: viewModel.codeColorPalette,
            onSourceHover: onSourceHover,
            onGoToDefinition: onGoToDefinition,
            sourceContextMenuItems: sourceContextMenuItems
        )
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
        EditorSceneViewportView(
            document: document,
            inspectorViewModel: inspectorViewModel,
            playModeState: playModeState,
            onDocumentChanged: { updatedDocument in
                viewModel.replaceSceneDocument(updatedDocument)
            }
        )
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

private struct EditorPreviewPanel: View {
    let status: EditorPreviewStatus
    let selectedPreviewID: String?
    let onSelectPreview: (EditorPreviewDeclaration) -> Void
    let onRebuild: () -> Void
    let onShowBuildOutput: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 34)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.editorColors.background)
        .accessibilityIdentifier("AdaEditor.PreviewPanel")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Preview")
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            previewSelector
            Spacer()
            Button(action: onRebuild) {
                Text("Refresh")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surfaceElevated))
            }
            .buttonStyle(DefaultButtonStyle())
        }
        .padding(.horizontal, 12)
        .background(theme.editorColors.surface)
    }

    @ViewBuilder
    private var previewSelector: some View {
        let declarations = declarations
        if declarations.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(declarations, id: \.id) { declaration in
                        Button(action: { onSelectPreview(declaration) }) {
                            Text(declaration.title)
                                .font(.system(size: 10))
                                .foregroundColor(declaration.id == selectedPreviewID ? theme.editorColors.text : theme.editorColors.muted)
                                .padding(.horizontal, 7)
                                .frame(height: 22)
                                .background(RoundedRectangleShape(cornerRadius: 5).fill(selectorBackground(for: declaration)))
                        }
                        .buttonStyle(DefaultButtonStyle())
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .hidden:
            EmptyView()
        case .unavailable(let message):
            messageView(title: "Preview unavailable", message: message)
        case .available(let declarations):
            let selected = declarations.first { $0.id == selectedPreviewID } ?? declarations.first
            messageView(title: selected?.title ?? "Preview", message: "Build the preview to render it.")
        case .building(let declaration, let message):
            progressView(title: declaration.title, message: message)
        case .loaded(_, let view):
            EditorPreviewLoadedView(previewView: view)
                .padding(12)
        case .failed(let declaration, let message, let hasBuildOutput):
            messageView(title: declaration?.title ?? "Preview failed", message: message, showsBuildOutputButton: hasBuildOutput)
        }
    }

    private var declarations: [EditorPreviewDeclaration] {
        switch status {
        case .available(let declarations):
            return declarations
        case .building(let declaration, _), .loaded(let declaration, _):
            return [declaration]
        case .failed(let declaration, _, _):
            return declaration.map { [$0] } ?? []
        case .hidden, .unavailable:
            return []
        }
    }

    private func selectorBackground(for declaration: EditorPreviewDeclaration) -> Color {
        declaration.id == selectedPreviewID ? theme.editorColors.blue.opacity(0.22) : theme.editorColors.surfaceElevated
    }

    private func progressView(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(theme.editorColors.text)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            RoundedRectangleShape(cornerRadius: 2)
                .fill(theme.editorColors.blue.opacity(0.32))
                .frame(width: 180, height: 4)
                .overlay(anchor: .leading) {
                    RoundedRectangleShape(cornerRadius: 2)
                        .fill(theme.editorColors.blue)
                        .frame(width: 72, height: 4)
                }
            showBuildOutputButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func messageView(title: String, message: String, showsBuildOutputButton: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(theme.editorColors.text)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            if showsBuildOutputButton {
                showBuildOutputButton
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var showBuildOutputButton: some View {
        Button(action: onShowBuildOutput) {
            Text("Show Build Output")
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.blue)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
        }
        .buttonStyle(DefaultButtonStyle())
    }
}

private struct EditorPreviewLoadedView: UIViewRepresentable {
    final class Coordinator {
        weak var currentPreviewView: UIView?
    }

    let previewView: UIView

    func makeUIView(in context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ view: UIView, in context: Context) {
        if context.coordinator.currentPreviewView !== previewView {
            context.coordinator.currentPreviewView?.removeFromParentView()
            view.addSubview(previewView)
            context.coordinator.currentPreviewView = previewView
        }

        previewView.frame = view.bounds
    }

    func sizeThatFits(_ proposal: ProposedViewSize, view: UIView, context: Context) -> Size {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
