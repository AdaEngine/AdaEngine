import Observation

/// Registration surface handed to an extension during activation.
@MainActor
public final class EditorExtensionContext {
    public let manifest: EditorExtensionManifest
    public private(set) weak var host: (any EditorHostServices)?
    fileprivate var staged: [any EditorContribution] = []

    fileprivate init(manifest: EditorExtensionManifest, host: (any EditorHostServices)?) {
        self.manifest = manifest
        self.host = host
    }

    public func register(_ contribution: some EditorContribution) {
        staged.append(contribution)
    }
}

/// Holds every active extension and its contributions.
@MainActor
@Observable
public final class EditorExtensionRegistry {
    public private(set) var panels: [PanelContribution] = []
    public private(set) var documentEditors: [DocumentEditorContribution] = []
    public private(set) var commands: [CommandContribution] = []
    public private(set) var inspectors: [InspectorContribution] = []
    public private(set) var viewportTools: [ViewportToolContribution] = []
    public private(set) var newFileTemplates: [NewFileTemplateContribution] = []
    public private(set) var activeExtensionIDs: [String] = []

    @ObservationIgnored private var extensions: [String: any EditorExtension] = [:]
    @ObservationIgnored private var owners: [String: String] = [:]
    @ObservationIgnored private var ownedIDs: [String: [String]] = [:]
    @ObservationIgnored private let platform: EditorExtensionPlatform
    @ObservationIgnored public weak var host: (any EditorHostServices)?

    public init(platform: EditorExtensionPlatform = .current, host: (any EditorHostServices)? = nil) {
        self.platform = platform
        self.host = host
    }

    /// Activates `extension`. Nothing is registered when this throws.
    public func activate(_ editorExtension: some EditorExtension) throws {
        let manifest = editorExtension.manifest
        guard manifest.apiVersion <= EditorExtensionManifest.currentAPIVersion else {
            throw EditorExtensionError.unsupportedAPIVersion(
                extensionID: manifest.id,
                requested: manifest.apiVersion,
                supported: EditorExtensionManifest.currentAPIVersion
            )
        }
        guard manifest.platforms.contains(platform) else {
            throw EditorExtensionError.unsupportedPlatform(extensionID: manifest.id, platform: platform)
        }
        guard extensions[manifest.id] == nil else {
            throw EditorExtensionError.duplicateExtension(manifest.id)
        }

        let context = EditorExtensionContext(manifest: manifest, host: host)
        do {
            try editorExtension.activate(in: context)
            try validate(context.staged, manifest: manifest)
        } catch {
            editorExtension.deactivate()
            throw error
        }
        for contribution in context.staged {
            insert(contribution)
            owners[contribution.id] = manifest.id
        }
        ownedIDs[manifest.id] = context.staged.map(\.id)
        extensions[manifest.id] = editorExtension
        activeExtensionIDs.append(manifest.id)
    }

    /// Removes every contribution of the extension, then notifies it.
    public func deactivate(extensionID: String) {
        guard let editorExtension = extensions.removeValue(forKey: extensionID) else {
            return
        }
        let ids = Set(ownedIDs.removeValue(forKey: extensionID) ?? [])
        for id in ids { owners[id] = nil }
        panels.removeAll { ids.contains($0.id) }
        documentEditors.removeAll { ids.contains($0.id) }
        commands.removeAll { ids.contains($0.id) }
        inspectors.removeAll { ids.contains($0.id) }
        viewportTools.removeAll { ids.contains($0.id) }
        newFileTemplates.removeAll { ids.contains($0.id) }
        activeExtensionIDs.removeAll { $0 == extensionID }
        editorExtension.deactivate()
    }

    /// The editor for a file extension, in registration order.
    public func documentEditor(forFileExtension fileExtension: String) -> DocumentEditorContribution? {
        let key = fileExtension.lowercased()
        return documentEditors.first { $0.fileExtensions.contains(key) }
    }

    public func inspector(forComponentType componentType: String) -> InspectorContribution? {
        inspectors.first { $0.componentType == componentType }
    }

    private func validate(_ staged: [any EditorContribution], manifest: EditorExtensionManifest) throws {
        var seen: Set<String> = []
        for contribution in staged {
            if let existing = owners[contribution.id] {
                throw EditorExtensionError.duplicateContribution(id: contribution.id, owner: manifest.id, existingOwner: existing)
            }
            guard seen.insert(contribution.id).inserted else {
                throw EditorExtensionError.duplicateContribution(id: contribution.id, owner: manifest.id, existingOwner: manifest.id)
            }
            let missing = contribution.requiredPermissions
                .subtracting(manifest.permissions)
                .sorted { $0.rawValue < $1.rawValue }
            if let permission = missing.first {
                throw EditorExtensionError.missingPermission(extensionID: manifest.id, contributionID: contribution.id, permission: permission)
            }
        }
    }

    private func insert(_ contribution: any EditorContribution) {
        switch contribution {
        case let value as PanelContribution: panels.append(value)
        case let value as DocumentEditorContribution: documentEditors.append(value)
        case let value as CommandContribution: commands.append(value)
        case let value as InspectorContribution: inspectors.append(value)
        case let value as ViewportToolContribution: viewportTools.append(value)
        case let value as NewFileTemplateContribution: newFileTemplates.append(value)
        default: assertionFailure("Unknown contribution type \(type(of: contribution))")
        }
    }
}
