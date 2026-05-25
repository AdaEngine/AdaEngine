@_spi(AdaEngine) import AdaEngine

struct EditorAgentSidebar: View {
    let viewModel: EditorAgentViewModel

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
            }
            modeSelector
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

    private var modeSelector: some View {
        HStack(spacing: 5) {
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

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let session = viewModel.activeSession, !session.events.isEmpty {
                    ForEach(session.events, id: \.id) { event in
                        eventRow(event)
                    }
                } else {
                    Text(viewModel.statusMessage ?? "No messages yet.")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.muted)
                        .padding(12)
                }
            }
            .padding(10)
        }
    }

    private func eventRow(_ event: EditorAgentEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eventTitle(event))
                .font(.system(size: 10))
                .foregroundColor(eventColor(event))
            if let message = event.message {
                ForEach(Array(message.segments.enumerated()), id: \.offset) { _, segment in
                    segmentView(segment, role: message.role)
                }
            } else if let details = event.details {
                Text(details)
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(8)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(eventBackground(event)))
        .overlay {
            RoundedRectangleShape(cornerRadius: 6)
                .stroke(theme.editorColors.border.opacity(0.35), lineWidth: 1)
        }
    }

    private func segmentView(_ segment: EditorAgentMessageSegment, role: EditorAgentRole) -> some View {
        switch segment.kind {
        case .text, .thinking:
            Text(segment.text ?? "")
                .font(.system(size: 11))
                .foregroundColor(role == .user ? theme.editorColors.text : theme.editorColors.muted)
                .lineLimit(12)
        case .attachment:
            Text(segment.attachment?.relativePath ?? segment.attachment?.name ?? "Attachment")
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.blue)
                .lineLimit(1)
        case .skill:
            Text("/\(segment.skill?.name ?? "skill")")
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.purple)
                .lineLimit(1)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            sceneContextIndicator
            skillStrip
            autocompleteList
            TextField("Ask the agent. Use @ to attach files.", text: viewModel.promptBinding)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 9)
                .frame(height: 34)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.background))
                .textFieldStyle(PlainTextFieldStyle())
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
            }
        }
        .padding(10)
        .background(theme.editorColors.surface)
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
    private var skillStrip: some View {
        if !viewModel.availableSkills.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(viewModel.availableSkills, id: \.id) { skill in
                        Button(action: { viewModel.toggleSkill(skill) }) {
                            Text("/\(skill.name)")
                                .font(.system(size: 10))
                                .foregroundColor(viewModel.selectedSkillIDs.contains(skill.id) ? theme.editorColors.text : theme.editorColors.purple)
                                .padding(.horizontal, 7)
                                .frame(height: 22)
                                .background(
                                    RoundedRectangleShape(cornerRadius: 5)
                                        .fill(viewModel.selectedSkillIDs.contains(skill.id) ? theme.editorColors.purple.opacity(0.22) : theme.editorColors.purple.opacity(0.08))
                                )
                        }
                        .buttonStyle(DefaultButtonStyle())
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
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

    private func eventTitle(_ event: EditorAgentEvent) -> String {
        if let title = event.title {
            return title
        }
        if let role = event.message?.role {
            return role.rawValue.uppercased()
        }
        return event.kind.rawValue
    }

    private func eventColor(_ event: EditorAgentEvent) -> Color {
        switch event.kind {
        case .error:
            return theme.editorColors.purple
        case .toolCall, .toolResult, .permission:
            return theme.editorColors.blue
        case .message, .runStatus:
            return theme.editorColors.muted
        }
    }

    private func eventBackground(_ event: EditorAgentEvent) -> Color {
        if event.message?.role == .user {
            return theme.editorColors.blue.opacity(0.10)
        }
        return theme.editorColors.surface
    }
}
