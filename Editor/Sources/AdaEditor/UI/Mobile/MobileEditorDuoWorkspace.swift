#if os(iOS)
@_spi(AdaEngine) import AdaEngine
import Foundation

struct MobileEditorDuoGamePane: View {
    @Environment(\.theme) private var theme
    let project: MobileEditorProject
    let runtime: EditorAdaScriptProjectRuntimeSession?
    let message: String?
    @Binding var selection: MobileEditorWorkspaceTab
    let openFile: (String) -> Void
    let fullscreen: () -> Void
    @State private var restartError: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(selection == .files ? "Files" : "Play")
                    .font(MobileEditorFont.font(size: 14))
                    .foregroundColor(theme.editorColors.muted)
                Spacer()
                Button {
                    do { try runtime?.restart(); restartError = nil }
                    catch { restartError = error.localizedDescription }
                } label: {
                    Text("\u{E5D5}").font(AdaEditorMaterialSymbolFont.font(size: 22))
                        .frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("AdaEditor.Duo.Restart")
                Button(action: fullscreen) {
                    Text("\u{E5D0}").font(AdaEditorMaterialSymbolFont.font(size: 22))
                        .frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("AdaEditor.Duo.Fullscreen")
            }
            .foregroundColor(theme.editorColors.text)
            .buttonStyle(DefaultButtonStyle())
            if selection == .files {
                MobileEditorFilesScreen(project: project, onOpenFile: openFile)
            } else if let runtime {
                runtime.view
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .mask(RoundedRectangleShape(cornerRadius: 16))
                    .accessibilityIdentifier("AdaEditor.Duo.GameViewport")
            } else {
                Text(message ?? "Create your game with Ada. Your preview will appear here.")
                    .font(MobileEditorFont.font(size: 15))
                    .foregroundColor(theme.editorColors.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                HStack(spacing: 4) {
                    paneButton("Scene", selected: selection != .files) { selection = .build }
                    paneButton("Files", selected: selection == .files) { selection = .files }
                }
                .padding(4)
                .background(CapsuleShape().fill(theme.editorColors.surface))
                Spacer()
            }
            .font(MobileEditorFont.font(size: 13))
            .foregroundColor(theme.editorColors.text)
            .buttonStyle(DefaultButtonStyle())
            if let restartError {
                Text(restartError).font(MobileEditorFont.font(size: 12)).foregroundColor(theme.editorColors.muted)
            }
        }
        .padding(12)
        .accessibilityIdentifier("AdaEditor.Duo.GamePane")
    }

    private func paneButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .foregroundColor(selected ? .white : theme.editorColors.text)
            .frame(width: 88, height: 44)
            .background(CapsuleShape().fill(selected ? theme.editorColors.blue : .clear))
            .accessibilityIdentifier("AdaEditor.Duo.\(title)")
    }
}

struct MobileEditorInlineComposer: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    let attachmentURLs: [URL]
    let isWorking: Bool
    let removeAttachment: (URL) -> Void
    let pasteImages: @MainActor () -> Bool
    let pickFiles: @MainActor () -> Void
    let pickPhotos: @MainActor () -> Void
    let submit: () -> Void
    let voice: () -> Void

    var body: some View {
        EditorAgentComposerSurface(cornerRadius: 24, horizontalInset: 12, topInset: 12, bottomInset: 12, usesGlass: true) {
            VStack(spacing: 8) {
                ZStack(anchor: .topLeading) {
                    TextEditor(text: _text, showsLineNumbers: false, showsScrollIndicators: true, wrapsLines: true)
                        .onTextEditorPaste(pasteImages)
                        .font(MobileEditorFont.font(size: 16))
                        .foregroundColor(theme.editorColors.text)
                        .textEditorColors(TextEditorColors(background: .clear, border: .clear, focusedBorder: .clear,
                            gutter: .clear, gutterRule: .clear, currentLineBackground: .clear, selection: theme.editorColors.blue.opacity(0.24)))
                        .accessibilityIdentifier("AdaEditor.Duo.Prompt")
                    if text.isEmpty {
                        Text("Plan, ask, build…").font(MobileEditorFont.font(size: 16))
                            .foregroundColor(theme.editorColors.muted).padding(8).allowsHitTesting(false)
                    }
                }
                .frame(height: 64)
                if !attachmentURLs.isEmpty {
                    MobileEditorAttachmentPreviews(urls: attachmentURLs, remove: removeAttachment)
                }
                HStack {
                    Button {
                        ProjectOpenPicker.presentAgentAttachmentSourcePicker(pickFiles: pickFiles, pickPhotos: pickPhotos)
                    } label: { symbol("\u{E145}") }
                    .accessibilityIdentifier("AdaEditor.Duo.Attach")
                    Spacer()
                    Button(action: voice) { symbol("\u{E029}") }
                    .accessibilityIdentifier("AdaEditor.Duo.Voice")
                    Button(action: submit) { symbol("\u{E163}").foregroundColor(theme.editorColors.blue) }
                        .disabled(isWorking || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachmentURLs.isEmpty))
                        .accessibilityIdentifier("AdaEditor.Duo.Send")
                }
                .buttonStyle(DefaultButtonStyle())
                .foregroundColor(theme.editorColors.text)
            }
        }
        .accessibilityIdentifier("AdaEditor.Duo.Composer")
    }

    private func symbol(_ value: String) -> some View {
        Text(value).font(AdaEditorMaterialSymbolFont.font(size: 22)).frame(width: 44, height: 44)
    }
}

struct MobileEditorWorkspaceTabStyle: TabViewStyle {
    let expanded: Bool
    let compact: LiquidGlassTabBarStyle

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if expanded { configuration.content } else { compact.makeBody(configuration: configuration) }
    }
}
#endif
