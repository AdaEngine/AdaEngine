#if os(iOS) || os(Android)
@_spi(AdaEngine) import AdaEngine
import Foundation

struct MobileEditorPublishScreen: View {
    @State private var draft: EditorPublicationDraft
    @State private var busy = false
    @State private var message = ""
    @State private var submitted = false
    let projectURL: URL
    let close: () -> Void
    private let account = EditorCloudAccount.shared

    init(projectURL: URL, title: String, close: @escaping () -> Void) {
        self.projectURL = projectURL
        self.close = close
        _draft = State(initialValue: EditorPublicationDraft.load(at: projectURL, title: title))
    }

    var body: some View {
        EditorPublicationForm(
            title: Binding(get: { draft.title }, set: { draft.title = $0 }),
            description: Binding(get: { draft.description }, set: { draft.description = $0 }),
            cover: draft.cover,
            screenshots: draft.screenshots,
            busy: busy,
            message: message,
            primaryTitle: primaryTitle,
            primaryEnabled: !busy && (account.accountID == nil || !account.pro || (!submitted && (try? draft.validate()) != nil)),
            footerCaption: footerCaption,
            close: close,
            chooseCover: { pickImages(cover: true) },
            removeCover: { draft.cover = nil },
            addScreenshots: { pickImages(cover: false) },
            removeScreenshot: { url in draft.screenshots.removeAll { $0 == url } },
            primaryAction: primaryAction,
            refreshPlan: account.accountID != nil && !account.pro ? { run { try await account.refreshPlan() } } : nil
        )
        .onChange(of: draft.title) { _, _ in submitted = false }
        .onChange(of: draft.description) { _, _ in submitted = false }
        .onChange(of: draft.cover) { _, _ in submitted = false }
        .onChange(of: draft.screenshots) { _, _ in submitted = false }
        .onDisappear { try? draft.save(at: projectURL) }
    }

    private var primaryTitle: String {
        if busy {
            return "Please wait…"
        }
        if account.accountID == nil {
            return "Sign in to continue"
        }
        if !account.pro {
            return "Get Cloud Pro"
        }
        return submitted ? "Submitted for review" : "Submit for review"
    }

    private var footerCaption: String {
        if account.accountID == nil {
            return "Your draft stays saved on this device."
        }
        if !account.pro {
            return "Community publishing is included with Cloud Pro."
        }
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a title for your game."
        }
        if draft.title.utf8.count > 100 {
            return "Choose a shorter game title."
        }
        if draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a description for players."
        }
        if draft.description.utf8.count > 5000 {
            return "Shorten the game description."
        }
        if draft.cover == nil {
            return "Choose a cover to complete your listing."
        }
        return "Your game goes live after Community review."
    }

    private func primaryAction() {
        if account.accountID == nil {
            run { try await account.signInOnWebsite() }
        } else if !account.pro {
            run { try await account.buyPro() }
        } else {
            publish()
        }
    }

    private func pickImages(cover: Bool) {
        MobileEditorPlatform.pickPhotos { result in
            guard case .selected(let urls) = result else {
                if case .unavailable(let error) = result { message = error }
                return
            }
            do {
                let folder = projectURL.appendingPathComponent(".ada/publication-images")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let selected = cover ? Array(urls.prefix(1)) : Array(urls.prefix(max(0, 5 - draft.screenshots.count)))
                let copied = try selected.map { url -> URL in
                    #if os(iOS)
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    #endif
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 5_000_000 else { throw EditorPublicationError("Choose images up to 5 MB each.") }
                    let destination = folder.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
                    try FileManager.default.copyItem(at: url, to: destination)
                    return destination
                }
                if cover { draft.cover = copied.first } else { draft.screenshots += copied }
                try draft.save(at: projectURL)
            } catch { message = error.localizedDescription }
        }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else {
            return
        }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await action() } catch { message = error.localizedDescription }
        }
    }

    private func publish() {
        guard let owner = account.accountID else {
            return
        }
        let origin = account.server, submission = draft
        message = "Preparing app and uploading images…"
        run {
            let release = try await EditorProjectPublisher.shared.submit(projectURL: projectURL, draft: submission, owner: owner, server: origin)
            submitted = true
            message = release["status"].string == "approved"
                ? "Version \(release["number"].int ?? 1) is already approved."
                : "Version \(release["number"].int ?? 1) submitted for review."
        }
    }
}
#endif
