import AdaEngine

/// A platform the editor runs on. Extensions list the platforms they support.
public enum EditorExtensionPlatform: String, CaseIterable, Hashable, Sendable {
    case macOS
    case windows
    case linux
    case iOS
    case visionOS
    case android

    /// The platform of the running editor build.
    public static var current: EditorExtensionPlatform {
        #if os(macOS)
        return .macOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #elseif os(visionOS)
        return .visionOS
        #elseif os(iOS)
        return .iOS
        #elseif os(Android)
        return .android
        #else
        return .macOS
        #endif
    }
}

/// Capabilities an extension must declare before it can register the matching contribution.
public enum EditorExtensionPermission: String, CaseIterable, Hashable, Sendable {
    case documentsRead = "documents.read"
    case documentsWrite = "documents.write"
    case viewportInput = "viewport.input"
}

/// Identity, compatibility and requested permissions of an extension.
public struct EditorExtensionManifest: Hashable, Sendable {
    /// The API version implemented by this build of AdaEditorKit.
    public static let currentAPIVersion = 1

    public var id: String
    public var name: String
    public var version: String
    public var apiVersion: Int
    public var platforms: Set<EditorExtensionPlatform>
    public var permissions: Set<EditorExtensionPermission>

    public init(
        id: String,
        name: String,
        version: String = "1.0.0",
        apiVersion: Int = EditorExtensionManifest.currentAPIVersion,
        platforms: Set<EditorExtensionPlatform> = Set(EditorExtensionPlatform.allCases),
        permissions: Set<EditorExtensionPermission> = []
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.apiVersion = apiVersion
        self.platforms = platforms
        self.permissions = permissions
    }
}

/// An editor extension. Native extensions are linked statically into an editor build.
@MainActor
public protocol EditorExtension: AnyObject {
    var manifest: EditorExtensionManifest { get }

    /// Registers contributions. Throwing aborts activation and registers nothing.
    func activate(in context: EditorExtensionContext) throws

    /// Called after the registry removed every contribution of this extension.
    func deactivate()
}

extension EditorExtension {
    public func deactivate() {}
}

/// Errors reported by ``EditorExtensionRegistry``.
public enum EditorExtensionError: Error, Equatable, Sendable {
    case unsupportedAPIVersion(extensionID: String, requested: Int, supported: Int)
    case unsupportedPlatform(extensionID: String, platform: EditorExtensionPlatform)
    case duplicateExtension(String)
    case duplicateContribution(id: String, owner: String, existingOwner: String)
    case missingPermission(extensionID: String, contributionID: String, permission: EditorExtensionPermission)
}

extension EditorExtensionError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .unsupportedAPIVersion(id, requested, supported):
            "\(id) needs editor API \(requested), this editor provides \(supported)."
        case let .unsupportedPlatform(id, platform):
            "\(id) does not support \(platform.rawValue)."
        case let .duplicateExtension(id):
            "Extension \(id) is already active."
        case let .duplicateContribution(id, owner, existing):
            "\(owner) cannot register \(id): already registered by \(existing)."
        case let .missingPermission(id, contribution, permission):
            "\(id) must declare \(permission.rawValue) to register \(contribution)."
        }
    }
}
