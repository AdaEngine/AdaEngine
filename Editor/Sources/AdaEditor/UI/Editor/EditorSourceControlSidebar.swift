@_spi(AdaEngine) import AdaEngine

struct EditorSourceControlSidebar: View {
    let viewModel: EditorViewModel

    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle("SOURCE CONTROL", trailing: viewModel.sourceControl.snapshot.branchTitle, theme: theme)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    repositoryHeader
                    commitSection
                    changeSections
                    actionSection
                    branchSection
                }
                .padding(10)
            }
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private var repositoryHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(viewModel.sourceControl.snapshot.branchTitle)
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.text)
                    .lineLimit(1)
                Spacer()
                commandButton("Refresh", enabled: !viewModel.sourceControl.isRunning) {
                    viewModel.refreshSourceControl()
                }
            }
            let trackingTitle = viewModel.sourceControl.snapshot.trackingTitle
            if !trackingTitle.isEmpty {
                Text(trackingTitle)
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.blue)
                    .lineLimit(1)
            }
            Text(viewModel.sourceControl.statusMessage)
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.muted)
                .lineLimit(3)
        }
        .padding(9)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface))
    }

    private var commitSection: some View {
        section("COMMIT") {
            TextField("Commit message", text: viewModel.sourceControl.commitMessageBinding)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 9)
                .frame(height: 32)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.background))
                .textFieldStyle(PlainTextFieldStyle())

            HStack(spacing: 8) {
                commandButton("Commit", enabled: viewModel.sourceControl.canCommit) {
                    viewModel.commitSourceControlChanges()
                }
                commandButton("Stage All", enabled: !viewModel.sourceControl.isRunning && viewModel.sourceControl.hasChanges) {
                    viewModel.stageAllSourceControlFiles()
                }
                commandButton("Unstage All", enabled: !viewModel.sourceControl.isRunning && !viewModel.sourceControl.snapshot.stagedFiles.isEmpty) {
                    viewModel.unstageAllSourceControlFiles()
                }
            }
        }
    }

    private var changeSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            fileSection("STAGED", files: viewModel.sourceControl.snapshot.stagedFiles, actionTitle: "Unstage") { path in
                viewModel.unstageSourceControlFile(path)
            }
            fileSection("CHANGES", files: viewModel.sourceControl.snapshot.changedFiles, actionTitle: "Stage") { path in
                viewModel.stageSourceControlFile(path)
            }
            fileSection("UNTRACKED", files: viewModel.sourceControl.snapshot.untrackedFiles, actionTitle: "Stage") { path in
                viewModel.stageSourceControlFile(path)
            }
        }
    }

    private var actionSection: some View {
        section("ACTIONS") {
            HStack(spacing: 8) {
                commandButton("Stash", enabled: !viewModel.sourceControl.isRunning && viewModel.sourceControl.hasChanges) {
                    viewModel.stashSourceControlChanges()
                }
                commandButton("Pull", enabled: !viewModel.sourceControl.isRunning) {
                    viewModel.pullSourceControlChanges()
                }
                commandButton("Push", enabled: !viewModel.sourceControl.isRunning) {
                    viewModel.pushSourceControlChanges()
                }
            }
        }
    }

    private var branchSection: some View {
        section("BRANCHES") {
            HStack(spacing: 8) {
                TextField("new-branch", text: viewModel.sourceControl.newBranchNameBinding)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.background))
                    .textFieldStyle(PlainTextFieldStyle())
                commandButton("Create", enabled: viewModel.sourceControl.canCreateBranch) {
                    viewModel.createSourceControlBranch()
                }
            }

            if viewModel.sourceControl.snapshot.branches.isEmpty {
                emptyText("No local branches.")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(viewModel.sourceControl.snapshot.branches, id: \.id) { branch in
                        branchRow(branch)
                    }
                }
            }
        }
    }

    private func fileSection(_ title: String, files: [GitStatusEntry], actionTitle: String, action: @escaping (String) -> Void) -> some View {
        section("\(title) \(files.count)") {
            if files.isEmpty {
                emptyText("No files.")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(files, id: \.id) { file in
                        fileRow(file, actionTitle: actionTitle, action: action)
                    }
                }
            }
        }
    }

    private func fileRow(_ file: GitStatusEntry, actionTitle: String, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 7) {
            Text(statusBadge(for: file))
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.blue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.path)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                    .lineLimit(1)
                if let originalPath = file.originalPath {
                    Text(originalPath)
                        .font(.system(size: 9))
                        .foregroundColor(theme.editorColors.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            commandButton(actionTitle, enabled: !viewModel.sourceControl.isRunning) {
                action(file.path)
            }
        }
        .padding(.horizontal, 7)
        .frame(minHeight: 28, maxHeight: 34)
        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surface.opacity(0.58)))
    }

    private func branchRow(_ branch: GitBranch) -> some View {
        Button(action: { viewModel.checkoutSourceControlBranch(branch) }) {
            HStack(spacing: 7) {
                Text(branch.isCurrent ? "*" : "")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.blue)
                    .frame(width: 12)
                Text(branch.name)
                    .font(.system(size: 11))
                    .foregroundColor(branch.isCurrent ? theme.editorColors.text : theme.editorColors.muted)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(branch.isCurrent ? theme.editorColors.blue.opacity(0.18) : Color.clear))
        }
        .buttonStyle(DefaultButtonStyle())
        .disabled(viewModel.sourceControl.isRunning || branch.isCurrent)
    }

    private func statusBadge(for file: GitStatusEntry) -> String {
        if file.isUntracked {
            return "??"
        }

        return "\(file.indexStatus?.rawValue ?? " ")\(file.workingTreeStatus?.rawValue ?? " ")"
            .trimmingCharacters(in: .whitespaces)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.blue)
            content()
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(theme.editorColors.muted)
            .padding(.vertical, 2)
    }

    private func commandButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(enabled ? theme.editorColors.text : theme.editorColors.muted)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(enabled ? 0.20 : 0.07)))
        }
        .buttonStyle(DefaultButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }
}
