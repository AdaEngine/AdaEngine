@_spi(AdaEngine) import AdaEngine

struct EditorAgentSidebar: View {
    let viewModel: EditorAgentViewModel

    @State private var showsSkillPicker = false
    @State private var skillSearchText = ""
    @State private var showsContextPicker = false
    @State private var contextSearchText = ""
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle("AGENT", trailing: viewModel.connectionState.title, theme: theme)
            sessionToolbar
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            composer
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private var sessionToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.sessions, id: \.id) { session in
                            sessionButton(session)
                        }
                    }
                    .padding(.vertical, 2)
                    .fixedSize(horizontal: true, vertical: false)
                }
                Button(action: {
                    Task {
                        try? await viewModel.createSession()
                    }
                }) {
                    Text("+")
                        .font(.system(size: 14))
                        .foregroundColor(theme.editorColors.text)
                        .frame(width: 26, height: 24)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.18)))
                }
                .buttonStyle(DefaultButtonStyle())
                Button(action: { viewModel.deleteActiveSession() }) {
                    Text("×")
                        .font(.system(size: 13))
                        .foregroundColor(theme.editorColors.muted)
                        .frame(width: 26, height: 24)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surface))
                }
                .buttonStyle(DefaultButtonStyle())
                Button(action: { viewModel.connect() }) {
                    Text("Connect")
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.blue)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
        .padding(10)
        .background(theme.editorColors.surface)
    }

    private func sessionButton(_ session: EditorAgentSessionSummary) -> some View {
        let active = session.id == viewModel.activeSession?.id
        return Button(action: { viewModel.selectSession(session) }) {
            Text(session.title)
                .font(.system(size: 10))
                .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(active ? theme.editorColors.blue.opacity(0.20) : theme.editorColors.surfaceElevated))
                .overlay {
                    RoundedRectangleShape(cornerRadius: 5)
                        .stroke(active ? theme.editorColors.blue.opacity(0.60) : theme.editorColors.border.opacity(0.40), lineWidth: 1)
                }
        }
        .buttonStyle(DefaultButtonStyle())
    }

    @ViewBuilder
    private var configurationControls: some View {
        if viewModel.sessionConfiguration.selectors.isEmpty {
            fallbackModeSelector
        } else {
            ForEach(
                viewModel.sessionConfiguration.selectors.filter { $0.category != .other },
                id: \.id
            ) { selector in
                configurationSelector(selector)
            }
        }
    }

    private var fallbackModeSelector: some View {
        HStack(spacing: 5) {
            Text("MODE")
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.muted)
            ForEach(EditorAgentChatMode.allCases, id: \.rawValue) { mode in
                Button(action: { viewModel.mode = mode }) {
                    Text(mode.title)
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.mode == mode ? theme.editorColors.text : theme.editorColors.muted)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(viewModel.mode == mode ? theme.editorColors.purple.opacity(0.18) : Color.clear))
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
    }

    private func configurationSelector(_ selector: EditorAgentConfigurationSelector) -> some View {
        HStack(spacing: 5) {
            Text(selector.category.rawValue.uppercased())
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.muted)
                .frame(width: 62, alignment: .leading)
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(selector.choices, id: \.id) { choice in
                        let selected = selector.currentValueID == choice.id
                        Button(action: { viewModel.selectConfiguration(selectorID: selector.id, valueID: choice.id) }) {
                            Text(choice.name)
                                .font(.system(size: 10))
                                .foregroundColor(selected ? theme.editorColors.text : theme.editorColors.muted)
                                .padding(.horizontal, 7)
                                .frame(height: 22)
                                .background(
                                    RoundedRectangleShape(cornerRadius: 5)
                                        .fill(selected ? theme.editorColors.purple.opacity(0.18) : Color.clear)
                                )
                        }
                        .buttonStyle(DefaultButtonStyle())
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let session = viewModel.activeSession, !session.events.isEmpty {
                    ForEach(session.events, id: \.id) { event in
                        eventRow(event)
                    }
                } else {
                    emptyState
                }
            }
            .padding(10)
        }
    }

    private func eventRow(_ event: EditorAgentEvent) -> some View {
        EditorAgentEventCard(event: event, viewModel: viewModel)
    }

    private var contextControls: some View {
        HStack(spacing: 6) {
            Button(action: { showsContextPicker.toggle() }) {
                Text(viewModel.pendingAttachments.isEmpty ? "+ Context" : "Context · \(viewModel.pendingAttachments.count)")
                    .font(.system(size: 10))
                    .foregroundColor(showsContextPicker ? theme.editorColors.text : theme.editorColors.blue)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(showsContextPicker ? 0.20 : 0.10)))
            }
            .buttonStyle(DefaultButtonStyle())
            .accessibilityIdentifier("AdaEditor.Agent.AddContext")
            Button(action: { viewModel.presentContextFilePicker() }) {
                Text("Browse")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.muted)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.surfaceElevated))
            }
            .buttonStyle(DefaultButtonStyle())
            .accessibilityIdentifier("AdaEditor.Agent.BrowseContext")
            Text("Files and images")
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.muted)
        }
    }

    @ViewBuilder
    private var contextPicker: some View {
        if showsContextPicker {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Search project files", text: Binding(get: { contextSearchText }, set: { contextSearchText = $0 }))
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.background))
                    .textFieldStyle(PlainTextFieldStyle())
                    .accessibilityIdentifier("AdaEditor.Agent.ContextSearch")
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.contextFiles(matching: contextSearchText), id: \.id) { entry in
                            Button(action: { viewModel.attachProjectFile(entry) }) {
                                HStack(spacing: 6) {
                                    Text(contextFileLabel(entry.path))
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.editorColors.blue)
                                        .frame(width: 28)
                                    Text(entry.path)
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.editorColors.text)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 5)
                                .frame(height: 24)
                            }
                            .buttonStyle(DefaultButtonStyle())
                        }
                    }
                }
                .frame(height: 150)
            }
            .padding(6)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.border.opacity(0.45), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var pendingAttachmentList: some View {
        if !viewModel.pendingAttachments.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(viewModel.pendingAttachments, id: \.id) { attachment in
                        EditorAgentAttachmentCard(attachment: attachment) {
                            viewModel.removeAttachment(id: attachment.id)
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            sceneContextIndicator
            codeSelectionIndicator
            configurationControls
            contextControls
            contextPicker
            pendingAttachmentList
            skillControls
            skillPicker
            autocompleteList
            TextField("Ask the agent. Use @ to attach files.", text: viewModel.promptBinding)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 9)
                .frame(height: 34)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.background))
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityIdentifier("AdaEditor.Agent.Prompt")
            HStack(spacing: 8) {
                if !viewModel.pendingAttachments.isEmpty {
                    Text("\(viewModel.pendingAttachments.count) attached")
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.blue)
                }
                Spacer()
                Button(action: { viewModel.interrupt() }) {
                    Text("Stop")
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                }
                .buttonStyle(DefaultButtonStyle())
                Button(action: { viewModel.sendPrompt() }) {
                    Text(viewModel.isSending ? "Sending" : "Send")
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.text)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(viewModel.canSend ? 0.72 : 0.25)))
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.Agent.Send")
            }
        }
        .padding(10)
        .background(theme.editorColors.surface)
    }

    @ViewBuilder
    private var codeSelectionIndicator: some View {
        if let context = viewModel.codeSelection {
            VStack(alignment: .leading, spacing: 3) {
                Text("Selected code · \(context.lineDescription)")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                Text(context.documentRelativePath)
                    .font(.system(size: 9))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.purple.opacity(0.10)))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.purple.opacity(0.24), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var sceneContextIndicator: some View {
        if let context = viewModel.sceneContext {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(context.sceneTitle) · \(context.selectedEntityName)")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .lineLimit(1)
                Text(context.sceneRelativePath)
                    .font(.system(size: 9))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.blue.opacity(0.10)))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.blue.opacity(0.24), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var skillControls: some View {
        if !viewModel.availableSkills.isEmpty {
            HStack(spacing: 6) {
                Button(action: { showsSkillPicker.toggle() }) {
                    Text(viewModel.selectedSkillIDs.isEmpty ? "Skills" : "Skills · \(viewModel.selectedSkillIDs.count)")
                        .font(.system(size: 10))
                        .foregroundColor(showsSkillPicker ? theme.editorColors.text : theme.editorColors.purple)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            RoundedRectangleShape(cornerRadius: 5)
                                .fill(theme.editorColors.purple.opacity(showsSkillPicker ? 0.22 : 0.10))
                        )
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.Agent.Skills")

                if !viewModel.selectedSkills.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 5) {
                            ForEach(viewModel.selectedSkills, id: \.id) { skill in
                                Button(action: { viewModel.toggleSkill(skill) }) {
                                    Text("/\(skill.id) ×")
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.editorColors.text)
                                        .padding(.horizontal, 7)
                                        .frame(height: 22)
                                        .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.purple.opacity(0.18)))
                                }
                                .buttonStyle(DefaultButtonStyle())
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var skillPicker: some View {
        if showsSkillPicker {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Search skills", text: Binding(get: { skillSearchText }, set: { skillSearchText = $0 }))
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.background))
                    .textFieldStyle(PlainTextFieldStyle())
                    .accessibilityIdentifier("AdaEditor.Agent.SkillSearch")

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(filteredSkills, id: \.id) { skill in
                            Button(action: { viewModel.toggleSkill(skill) }) {
                                HStack(spacing: 6) {
                                    Text(viewModel.selectedSkillIDs.contains(skill.id) ? "✓" : "")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.editorColors.blue)
                                        .frame(width: 12)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("/\(skill.id)")
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.editorColors.text)
                                        if let description = skill.description {
                                            Text(description)
                                                .font(.system(size: 9))
                                                .foregroundColor(theme.editorColors.muted)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangleShape(cornerRadius: 5)
                                        .fill(viewModel.selectedSkillIDs.contains(skill.id) ? theme.editorColors.blue.opacity(0.10) : Color.clear)
                                )
                            }
                            .buttonStyle(DefaultButtonStyle())
                        }
                    }
                }
                .frame(height: 154)
            }
            .padding(6)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.border.opacity(0.45), lineWidth: 1)
            }
        }
    }

    private var filteredSkills: [EditorAgentSkill] {
        let query = skillSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return viewModel.availableSkills
        }
        return viewModel.availableSkills.filter { skill in
            skill.id.localizedCaseInsensitiveContains(query)
                || skill.name.localizedCaseInsensitiveContains(query)
                || skill.description?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What should we build?")
                .font(.system(size: 17))
                .foregroundColor(theme.editorColors.text)
            Text(viewModel.statusMessage ?? "The agent can work with code, scenes, assets, project documentation, and the live AdaEngine runtime.")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
                .lineLimit(4)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(promptSuggestions, id: \.self) { suggestion in
                    Button(action: { viewModel.prompt = suggestion }) {
                        Text(suggestion)
                            .font(.system(size: 10))
                            .foregroundColor(theme.editorColors.blue)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.blue.opacity(0.08)))
                    }
                    .buttonStyle(DefaultButtonStyle())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptSuggestions: [String] {
        if viewModel.sceneContext != nil {
            return [
                "Explain the selected entity and its components",
                "Improve this scene and verify it with a screenshot",
                "Find missing assets or invalid references"
            ]
        }
        if viewModel.codeSelection != nil {
            return [
                "Explain and improve the selected code",
                "Find related project code and tests",
                "Fix this code and validate the result"
            ]
        }
        return [
            "Build a playable scene for this project",
            "Find and fix current project errors",
            "Explain the project architecture"
        ]
    }

    @ViewBuilder
    private var autocompleteList: some View {
        if !viewModel.autocompleteSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.autocompleteSuggestions, id: \.id) { entry in
                    Button(action: { viewModel.insertAutocomplete(entry) }) {
                        HStack(spacing: 6) {
                            Text(entry.isDirectory ? "-" : "<>")
                                .font(.system(size: 9))
                                .foregroundColor(theme.editorColors.blue)
                                .frame(width: 18)
                            Text(entry.path)
                                .font(.system(size: 10))
                                .foregroundColor(theme.editorColors.muted)
                                .lineLimit(1)
                            Spacer()
                        }
                        .frame(height: 22)
                    }
                    .buttonStyle(DefaultButtonStyle())
                }
            }
            .padding(6)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.background))
        }
    }

    private func contextFileLabel(_ path: String) -> String {
        let fileExtension = URL(fileURLWithPath: path).pathExtension.uppercased()
        if ["PNG", "JPG", "JPEG", "GIF"].contains(fileExtension) {
            return "IMG"
        }
        return fileExtension.isEmpty ? "FILE" : String(fileExtension.prefix(4))
    }

}
