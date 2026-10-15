import AdaEngine
import Math

/// Where a panel prefers to appear. Hosts remap areas that do not exist on a platform.
public enum EditorPanelLocation: String, Hashable, Sendable {
    case left
    case right
    case bottom
    /// A full workbench tab, like the Scene or Script screens.
    case mainScreen
}

/// A contribution with a stable, registry-wide unique identifier.
public protocol EditorContribution {
    var id: String { get }
    /// Permissions the owning extension must have declared.
    var requiredPermissions: Set<EditorExtensionPermission> { get }
}

extension EditorContribution {
    public var requiredPermissions: Set<EditorExtensionPermission> { [] }
}

public struct PanelContribution: EditorContribution {
    public var id: String
    public var title: String
    public var icon: String?
    public var location: EditorPanelLocation
    public var makeView: @MainActor () -> AnyView

    public init(
        id: String,
        title: String,
        icon: String? = nil,
        location: EditorPanelLocation = .right,
        makeView: @escaping @MainActor () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.location = location
        self.makeView = makeView
    }
}

/// Identifies the file an editor was opened for.
public struct EditorDocumentReference: Hashable, Sendable {
    public var relativePath: String
    public var fileExtension: String

    public init(relativePath: String) {
        self.relativePath = relativePath
        fileExtension = relativePath.split(separator: ".").last.map { $0.lowercased() } ?? ""
    }
}

/// An editor for files with the given extensions: a new resource type.
public struct DocumentEditorContribution: EditorContribution {
    public var id: String
    public var title: String
    /// Lowercase extensions without a dot, such as `terrain`.
    public var fileExtensions: Set<String>
    public var makeView: @MainActor (EditorDocumentReference) -> AnyView
    public var requiredPermissions: Set<EditorExtensionPermission> { [.documentsRead] }

    public init(
        id: String,
        title: String,
        fileExtensions: Set<String>,
        makeView: @escaping @MainActor (EditorDocumentReference) -> AnyView
    ) {
        self.id = id
        self.title = title
        self.fileExtensions = Set(fileExtensions.map { $0.lowercased() })
        self.makeView = makeView
    }
}

public struct CommandContribution: EditorContribution {
    public var id: String
    public var title: String
    public var menuPath: [String]
    public var perform: @MainActor () -> Void

    public init(id: String, title: String, menuPath: [String] = [], perform: @escaping @MainActor () -> Void) {
        self.id = id
        self.title = title
        self.menuPath = menuPath
        self.perform = perform
    }
}

/// A custom inspector control for one component type.
public struct InspectorContribution: EditorContribution {
    public var id: String
    public var componentType: String
    public var makeView: @MainActor () -> AnyView
    public var requiredPermissions: Set<EditorExtensionPermission> { [.documentsRead, .documentsWrite] }

    public init(id: String, componentType: String, makeView: @escaping @MainActor () -> AnyView) {
        self.id = id
        self.componentType = componentType
        self.makeView = makeView
    }
}

public struct NewFileTemplateContribution: EditorContribution {
    public var id: String
    public var title: String
    public var fileExtension: String
    public var defaultContent: String

    public init(id: String, title: String, fileExtension: String, defaultContent: String) {
        self.id = id
        self.title = title
        self.fileExtension = fileExtension
        self.defaultContent = defaultContent
    }
}

/// Input devices a viewport tool can handle. Extensions must not require hover or a keyboard.
public struct ViewportInputStyles: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let pointer = ViewportInputStyles(rawValue: 1 << 0)
    public static let touch = ViewportInputStyles(rawValue: 1 << 1)
    public static let pencil = ViewportInputStyles(rawValue: 1 << 2)
    public static let all: ViewportInputStyles = [.pointer, .touch, .pencil]
}

public enum ViewportToolPhase: Hashable, Sendable {
    case began
    case changed
    case ended
    case cancelled
}

/// One input sample in the scene viewport.
public struct ViewportToolEvent: Sendable {
    public var phase: ViewportToolPhase
    /// Location in viewport points.
    public var location: Point
    /// Ray from the camera through `location` in world space.
    public var worldRay: Ray?
    public var pressure: Float

    public init(phase: ViewportToolPhase, location: Point, worldRay: Ray? = nil, pressure: Float = 1) {
        self.phase = phase
        self.location = location
        self.worldRay = worldRay
        self.pressure = pressure
    }
}

/// Handles viewport input. A stroke is `began`, any number of `changed`, then `ended` or `cancelled`.
@MainActor
public protocol ViewportToolHandler: AnyObject {
    func handle(_ event: ViewportToolEvent, host: any EditorHostServices)
}

public struct ViewportToolContribution: EditorContribution {
    public var id: String
    public var title: String
    public var icon: String?
    public var inputStyles: ViewportInputStyles
    public var makeHandler: @MainActor () -> any ViewportToolHandler
    public var requiredPermissions: Set<EditorExtensionPermission> { [.viewportInput, .documentsWrite] }

    public init(
        id: String,
        title: String,
        icon: String? = nil,
        inputStyles: ViewportInputStyles = .all,
        makeHandler: @escaping @MainActor () -> any ViewportToolHandler
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.inputStyles = inputStyles
        self.makeHandler = makeHandler
    }
}
