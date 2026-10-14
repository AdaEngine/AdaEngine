#if os(iOS)
@_spi(AdaEngine) import AdaEngine
import AdaUtils
import Foundation

struct MobileEditorWorkspaceView: View {
    @Environment(\.theme) private var theme
    @Environment(\.navigationBarContentInset) private var navigationBarContentInset
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.navigationContentSideInsets) private var navigationSideInsets
    @Environment(\.navigationBarControlsAxis) private var navigationControlsAxis
    @Environment(\.deviceHinge) private var deviceHinge
    @Environment(\.displaySafeAreaInsets) private var displaySafeAreaInsets
    @Environment(\.keyboardSafeAreaInset) private var keyboardSafeAreaInset
    let project: MobileEditorProject
    @Binding var selection: MobileEditorWorkspaceTab
    @Binding var promptDraft: String
    let isComposerPresented: Bool
    let pendingAttachments: [URL]
    let chatEvents: [EditorAgentEvent]
    let sessionID: String
    var a2uiPresentation: EditorAgentA2UIPresentation? = nil
    let previousSession: MobileEditorChatSessionReference?
    let resumePreviousSession: () -> Void
    let agentStatus: String?
    let agentActivityState: EditorAgentActivityState
    let agentActivityID: String?
    let preparePlay: () -> Void
    let onOpenFile: (String) -> Void
    let openPrompt: () -> Void
    let openVoice: () -> Void
    let embeddedRuntime: EditorAdaScriptProjectRuntimeSession?
    let prepareEmbeddedPlay: () -> Void
    let topAccessory: AnyView
    let inlineComposer: AnyView

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - navigationSideInsets.leading - navigationSideInsets.trailing)
            let physicalContentHeight = geometry.size.height + keyboardSafeAreaInset
            let tabletop = deviceHinge?.status == .partiallyOpen && physicalContentHeight > contentWidth
            // The keyboard covers the game pane; it must not change the device's posture layout.
            let contentSize = Size(width: contentWidth, height: tabletop ? physicalContentHeight : geometry.size.height)
            let nativeDivision = geometry.reservedRegions(kind: .division).first.map { region in
                ViewReservedRegion(id: region.id, kind: region.kind,
                    frame: Rect(x: region.frame.minX - navigationSideInsets.leading, y: region.frame.minY,
                        width: region.frame.width, height: region.frame.height),
                    margins: region.margins, isActive: region.isActive)
            }
            // UIKit can omit division regions during a partial fold. Preserve the
            // physical display midpoint even when the host consumes its top safe area.
            let fallbackDivision: ViewReservedRegion? = if tabletop {
                ViewReservedRegion(
                    id: "workspace-hinge",
                    kind: .division,
                    frame: Rect(
                        x: 0,
                        y: (geometry.frame(in: .global).minY + physicalContentHeight + displaySafeAreaInsets.bottom) * 0.5 - geometry.frame(in: .global).minY,
                        width: contentSize.width,
                        height: 0
                    ),
                    margins: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
                )
            } else { nil }
            let division = nativeDivision ?? fallbackDivision
            let layout = AdaptiveSplitFrames(size: contentSize, horizontalSizeClass: horizontalSizeClass,
                division: division, hinge: deviceHinge)
            let stacked = layout.isExpanded && layout.primary.maxY <= layout.secondary.minY
            let gameFrame = stacked ? layout.secondary : layout.primary
            let chatFrame = stacked ? layout.primary : layout.secondary
            ZStack(anchor: .topLeading) {
                // Offsets do not contribute to stack measurement; include both panes in the host bounds.
                Color.clear.frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
                if layout.isExpanded {
                    MobileEditorDuoGamePane(project: project, runtime: embeddedRuntime, message: agentStatus,
                        selection: _selection, openFile: onOpenFile, fullscreen: preparePlay, showsControls: !stacked)
                        .padding(.top, max(0, navigationBarContentInset - gameFrame.minY))
                        .frame(width: gameFrame.width, height: gameFrame.height)
                        .offset(x: navigationSideInsets.leading + gameFrame.minX, y: gameFrame.minY)
                }
                VStack(spacing: 0) {
                    if stacked {
                        MobileEditorDuoTopControls(runtime: embeddedRuntime, selection: _selection, fullscreen: preparePlay)
                    }
                    activeContent(expanded: layout.isExpanded)
                }
                    .id("workspace-content")
                    .padding(.top, layout.isExpanded ? max(0, navigationBarContentInset - chatFrame.minY) : 0)
                    .frame(width: layout.isExpanded ? chatFrame.width : geometry.size.width, height: chatFrame.height)
                    .offset(x: layout.isExpanded ? navigationSideInsets.leading + chatFrame.minX : 0, y: chatFrame.minY)
                if !layout.isExpanded, navigationControlsAxis != .vertical {
                    topAccessory.padding(.trailing, 16).padding(.top, navigationBarContentInset + 8)
                        .frame(width: contentSize.width, height: geometry.size.height, alignment: .topTrailing)
                        .offset(x: navigationSideInsets.leading)
                }
            }
            .onAppear { if layout.isExpanded { prepareEmbeddedPlay() } }
            .onChange(of: layout.isExpanded) { _, expanded in if expanded { prepareEmbeddedPlay() } }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .mask(RectangleShape())
        .background(theme.editorColors.background)
        .overlay(anchor: .topLeading) {
            if selection == .build, let previousSession {
                Button(action: resumePreviousSession) {
                    HStack(spacing: 7) {
                        Text("\u{E5C4}").font(AdaEditorMaterialSymbolFont.font(size: 17))
                        Text("Back to \(previousSession.title)")
                            .font(MobileEditorFont.font(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Capsule().fill(theme.editorColors.surface))
                }
                .buttonStyle(DefaultButtonStyle())
                .disabled(agentActivityState == .working)
                .accessibilityIdentifier("AdaEditor.Mobile.BackToSession")
                .padding(.horizontal, 16)
                .padding(.top, navigationBarContentInset + 8)
            }
        }
        .overlay {
            EditorAgentActivityOverlay(state: agentActivityState, activityID: agentActivityID)
        }
    }

    @ViewBuilder
    private func activeContent(expanded: Bool) -> some View {
        TabView(selection: Binding(
            get: { expanded ? .build : selection },
            set: { tab in
                if tab == .play { preparePlay() } else { selection = tab }
            }
        )) {
            Tab("Build", value: MobileEditorWorkspaceTab.build) {
                MobileEditorBuildScreen(
                    project: project,
                    promptDraft: _promptDraft,
                    isComposerPresented: isComposerPresented,
                    attachmentURLs: pendingAttachments,
                    chatEvents: chatEvents,
                    sessionID: sessionID,
                    a2uiPresentation: a2uiPresentation,
                    previousSession: previousSession,
                    agentStatus: agentStatus,
                    isWorking: agentActivityState == .working,
                    openPrompt: openPrompt,
                    openVoice: openVoice,
                    inlineComposer: expanded ? inlineComposer : nil,
                    topAccessory: expanded ? topAccessory : nil
                )
            }
            Tab("Files", value: MobileEditorWorkspaceTab.files) {
                MobileEditorFilesScreen(project: project, onOpenFile: onOpenFile)
            }
            if navigationControlsAxis != .vertical {
                Tab("Play", value: MobileEditorWorkspaceTab.play, placement: .floating) {
                    EmptyView()
                }
            }
        }
        .tabViewPosition(.automatic)
        .tabViewStyle(MobileEditorWorkspaceTabStyle(expanded: expanded, compact: LiquidGlassTabBarStyle(
            backgroundColor: theme.editorColors.surface.opacity(0.12),
            borderColor: theme.editorColors.border,
            selectedColor: theme.editorColors.text,
            unselectedColor: theme.editorColors.muted,
            symbols: [
                "Build": "\u{E86F}",
                "Files": "\u{E2C7}",
                "Play": "\u{E037}"
            ],
            symbolFont: AdaEditorMaterialSymbolFont.font(size: 22),
            labelFont: MobileEditorFont.font(size: 11),
            bottomPadding: 6,
            sideControlsClearance: 248
        )))
    }
}
struct MobileEditorBuildScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.navigationBarContentInset) private var navigationBarContentInset
    let project: MobileEditorProject
    @Binding var promptDraft: String
    let isComposerPresented: Bool
    let attachmentURLs: [URL]
    let chatEvents: [EditorAgentEvent]
    let sessionID: String
    var a2uiPresentation: EditorAgentA2UIPresentation? = nil
    let previousSession: MobileEditorChatSessionReference?
    let agentStatus: String?
    let isWorking: Bool
    let openPrompt: () -> Void
    let openVoice: () -> Void
    var inlineComposer: AnyView? = nil
    var topAccessory: AnyView? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(anchor: .bottom) {
                if chatEvents.isEmpty {
                    VStack(spacing: 24) {
                        if inlineComposer == nil || geometry.size.height >= 340 {
                            Text("What would you like\nto create today?")
                                .font(MobileEditorFont.font(size: 25))
                                .foregroundColor(theme.editorColors.text)
                                .multilineTextAlignment(.center)
                        }
                        if inlineComposer == nil {
                            composer
                                .frame(width: max(0, min(620, geometry.size.width - 32)))
                                .padding(.horizontal, 16)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, inlineComposer == nil ? 100 : 0)
                    if let inlineComposer {
                        inlineComposer
                            .frame(width: max(0, geometry.size.width - 32))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                } else {
                    transcript
                    LinearGradient(
                        colors: [theme.editorColors.background.opacity(0), theme.editorColors.background.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)
                    .allowsHitTesting(false)
                    VStack(spacing: 8) {
                        if let agentStatus {
                            HStack(spacing: 6) {
                                if isWorking {
                                    Circle().fill(theme.editorColors.blue).frame(width: 6, height: 6)
                                }
                                Text(agentStatus)
                            }
                                .font(MobileEditorFont.font(size: 11))
                                .foregroundColor(theme.editorColors.muted)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isWorking {
                            Text("You can switch screens while Ada works.")
                                .font(.system(size: 11))
                                .foregroundColor(theme.editorColors.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        composer
                            .frame(width: max(0, min(620, geometry.size.width - 32)))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, inlineComposer == nil ? 100 : 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(anchor: .topLeading) {
            if inlineComposer != nil {
                HStack(spacing: 8) {
                    Text("\u{E65F}").font(AdaEditorMaterialSymbolFont.font(size: 20)).foregroundColor(theme.editorColors.blue)
                    Text("Agent").font(MobileEditorFont.font(size: 16)).foregroundColor(theme.editorColors.text)
                    Spacer(minLength: 8)
                    if let topAccessory { topAccessory }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .accessibilityIdentifier("AdaEditor.Duo.AgentHeader")
            }
        }
    }

    @ViewBuilder
    private var composer: some View {
        if let inlineComposer { inlineComposer } else { promptLauncher }
    }

    private var transcript: some View {
        var transcript = EditorAgentTranscript(events: chatEvents, sessionID: sessionID)
        transcript.a2uiPresentation = a2uiPresentation
        transcript.contentInsets = EdgeInsets(top: inlineComposer != nil ? 52 : (previousSession == nil ? 0 : 54), leading: 16,
            bottom: inlineComposer != nil ? 180 : (agentStatus == nil ? 220 : 260), trailing: 16)
        transcript.scrollRespectsSafeArea = false
        transcript.scrollExtendsUnderNavigationBar = inlineComposer == nil
        return transcript
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private var promptLauncher: some View {
        MobileEditorPromptLauncher(
            promptDraft: _promptDraft,
            placeholder: project.prompt == nil ? "Create a game…" : "Describe your next change…",
            attachmentURLs: attachmentURLs,
            isWorking: isWorking,
            openPrompt: openPrompt,
            openVoice: openVoice
        )
        .opacity(isComposerPresented ? 0 : 1)
        .allowsHitTesting(!isComposerPresented)
    }
}

private struct MobileEditorPromptLauncher: View {
    @Environment(\.theme) private var theme
    @Binding var promptDraft: String
    let placeholder: String
    let attachmentURLs: [URL]
    let isWorking: Bool
    let openPrompt: () -> Void
    let openVoice: () -> Void

    var body: some View {
        EditorAgentComposerSurface(
            cornerRadius: 24,
            horizontalInset: 18,
            topInset: 14,
            bottomInset: 12,
            usesGlass: true
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: openPrompt) {
                    Text(hasDraft ? promptDraft : placeholder)
                        .font(MobileEditorFont.font(size: 14))
                        .foregroundColor(hasDraft ? theme.editorColors.text : theme.editorColors.muted)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.Mobile.OpenPrompt")
                if !attachmentURLs.isEmpty {
                    MobileEditorAttachmentPreviews(urls: attachmentURLs)
                }
                HStack(spacing: 18) {
                    Button(action: openPrompt) {
                        Text("\u{E145}")
                            .font(AdaEditorMaterialSymbolFont.font(size: 25))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(theme.editorColors.background.opacity(0.5)))
                    }
                    .accessibilityIdentifier("AdaEditor.Mobile.OpenPromptAttachments")
                    Spacer()
                    Button(action: openVoice) {
                        MobileEditorVoiceOrb(activity: isWorking ? .working : .idle)
                            .frame(width: 52, height: 52)
                            .allowsHitTesting(false)
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .accessibilityIdentifier("AdaEditor.Mobile.OpenVoice")
                }
                .foregroundColor(theme.editorColors.text)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }

    private var hasDraft: Bool { !promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct MobileEditorPlayEmptyScreen: View {
    @Environment(\.theme) private var theme
    let message: String?
    let showBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            MobileEditorSectionHeading(eyebrow: "Play", title: "Your game will appear here")
            Text(message ?? "Build a valid AdaScript project to see it here.")
                .font(MobileEditorFont.font(size: 15))
                .foregroundColor(theme.editorColors.muted)
            MobileEditorPrimaryButton(title: "Go to Build", action: showBuild)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.editorColors.background)
    }
}
#endif
