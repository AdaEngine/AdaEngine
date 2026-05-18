@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorCodeFileView: View {
    let document: EditorTextDocument
    let text: Binding<String>
    let fontSize: Double

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            codeHeader
            if let errorMessage = document.errorMessage {
                fileError(message: errorMessage)
            } else {
                codeEditor
            }
        }
        .background(theme.editorColors.background)
        .accessibilityIdentifier("AdaEditor.CodeFile.\(document.title)")
    }
}

private extension EditorCodeFileView {
    var codeHeader: some View {
        HStack(spacing: 8) {
            Text(document.title)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            Text(document.relativePath)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
            Text(document.language.rawValue.uppercased())
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.blue)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(theme.editorColors.surface)
    }

    var codeEditor: some View {
        TextEditor(text: text)
            .font(AdaEditorCodeFont.font(size: fontSize))
            .foregroundColor(theme.editorColors.text)
            .accentColor(theme.editorColors.blue)
            .textEditorColors(editorColors)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var editorColors: TextEditorColors {
        TextEditorColors(
            background: theme.editorColors.background,
            border: theme.editorColors.border.opacity(0.55),
            focusedBorder: theme.editorColors.blue,
            gutter: theme.editorColors.muted,
            gutterRule: theme.editorColors.border.opacity(0.45),
            currentLineBackground: theme.editorColors.blue.opacity(0.12),
            selection: theme.editorColors.blue.opacity(0.26)
        )
    }

    func fileError(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unable to open file")
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
}

enum AdaEditorCodeFont {
    private static let resource: FontResource? = {
        guard let fontURL = Foundation.Bundle.editor.url(
            forResource: "FiraCode-Regular",
            withExtension: "ttf",
            subdirectory: "Assets/Fonts"
        ) else {
            return nil
        }

        return FontResource.custom(
            fontPath: fontURL,
            emFontScale: 74,
            includeDefaultCharset: true,
            additionalCodepoints: []
        )
    }()

    static func font(size: Double) -> Font {
        guard let resource else {
            return .system(size: size)
        }

        return Font(fontResource: resource, pointSize: size)
    }
}
