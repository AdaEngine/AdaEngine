@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorNewFileDialog: View {
    let viewModel: EditorViewModel

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(anchor: .center) {
            Color.black.opacity(0.54)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                Text("New File")
                    .font(.system(size: 18))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.bottom, 6)

                Text("Choose a file type and name.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(EditorNewFileKind.allCases, id: \.self) { kind in
                        fileKindRow(kind)
                    }
                }
                .padding(4)
                .background(RoundedRectangleShape(cornerRadius: 7).fill(theme.editorColors.background))
                .overlay {
                    RoundedRectangleShape(cornerRadius: 7)
                        .stroke(theme.editorColors.border, lineWidth: 1)
                }
                .padding(.bottom, 16)

                Text("File name")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .padding(.bottom, 6)

                TextField("Name", text: viewModel.newFileNameBinding)
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(height: 32)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface))
                    .overlay {
                        RoundedRectangleShape(cornerRadius: 6)
                            .stroke(theme.editorColors.border, lineWidth: 1)
                    }
                    .accessibilityIdentifier("AdaEditor.NewFile.Name")

                HStack(spacing: 5) {
                    Text("Location: \(viewModel.newFileLocationTitle)")
                    Spacer()
                    Text(viewModel.newFileExtensionHint)
                }
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.muted)
                .padding(.top, 6)

                if let errorMessage = viewModel.newFileErrorMessage {
                    Text(errorMessage)
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 232 / 255, green: 96 / 255, blue: 96 / 255))
                        .padding(.top, 8)
                        .accessibilityIdentifier("AdaEditor.NewFile.Error")
                }

                HStack(spacing: 8) {
                    Spacer()
                    dialogButton(title: "Cancel", isPrimary: false) {
                        EditorNewFileDialogActions.cancel(viewModel: viewModel, dismiss: dismiss)
                    }
                    .accessibilityIdentifier("AdaEditor.NewFile.Cancel")

                    dialogButton(title: "Create", isPrimary: true) {
                        EditorNewFileDialogActions.create(viewModel: viewModel, dismiss: dismiss)
                    }
                    .disabled(viewModel.newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(viewModel.newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    .accessibilityIdentifier("AdaEditor.NewFile.Create")
                }
                .padding(.top, 18)
            }
            .padding(22)
            .frame(width: 440)
            .background(
                RoundedRectangleShape(cornerRadius: 12)
                    .fill(theme.editorColors.surfaceElevated)
            )
            .overlay {
                RoundedRectangleShape(cornerRadius: 12)
                    .stroke(theme.editorColors.border, lineWidth: 1)
            }
            .accessibilityIdentifier("AdaEditor.NewFile.Dialog")
        }
    }

    private func fileKindRow(_ kind: EditorNewFileKind) -> some View {
        let isSelected = viewModel.newFileKind == kind
        return Button(action: {
            viewModel.newFileKind = kind
            viewModel.newFileErrorMessage = nil
        }) {
            HStack(spacing: 10) {
                Text(fileKindIcon(kind))
                    .font(.system(size: 12))
                    .foregroundColor(kind == .scene ? theme.editorColors.purple : theme.editorColors.blue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 12))
                        .foregroundColor(theme.editorColors.text)
                    Text(kind.detail)
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.muted)
                }
                Spacer()
                Text(".\(kind.fileExtension)")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.muted)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(
                RoundedRectangleShape(cornerRadius: 5)
                    .fill(isSelected ? theme.editorColors.blue.opacity(0.22) : Color.clear)
            )
        }
        .buttonStyle(DefaultButtonStyle())
        .accessibilityIdentifier("AdaEditor.NewFile.Kind.\(kind.rawValue)")
    }

    private func dialogButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 12))
            .foregroundColor(isPrimary ? theme.editorColors.text : theme.editorColors.muted)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                RoundedRectangleShape(cornerRadius: 6)
                    .fill(isPrimary ? theme.editorColors.blue.opacity(0.28) : theme.editorColors.background)
            )
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(isPrimary ? theme.editorColors.blue.opacity(0.72) : theme.editorColors.border, lineWidth: 1)
            }
    }

    private func fileKindIcon(_ kind: EditorNewFileKind) -> String {
        switch kind {
        case .scene:
            "#"
        case .script, .swift:
            "<>"
        case .plainText:
            "="
        }
    }
}

@MainActor
enum EditorNewFileDialogActions {
    static func cancel(viewModel: EditorViewModel, dismiss: DismissAction) {
        viewModel.dismissNewFileDialog()
        dismiss()
    }

    @discardableResult
    static func create(viewModel: EditorViewModel, dismiss: DismissAction) -> Bool {
        guard viewModel.createNewFile() else {
            return false
        }

        dismiss()
        return true
    }
}
