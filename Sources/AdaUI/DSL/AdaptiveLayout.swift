import AdaUtils
import Math

/// The amount of space available along an axis, supplied by the containing window.
public enum UserInterfaceSizeClass: String, Codable, Hashable, Sendable {
    case compact
    case regular
}

/// The physical hinge associated with the current view's display. Absent on ordinary displays.
public struct DeviceHinge: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Hashable, Sendable {
        case unknown
        case closed
        case partiallyOpen
        case fullyOpen
    }

    public let status: Status
    /// The platform's hinge angle in radians.
    public let angle: Float

    public init(status: Status, angle: Float) {
        self.status = status
        self.angle = angle
    }

    /// Normalized opening: zero when closed, one when fully open.
    /// Intermediate angles are measured against a flat, pi-radian hinge.
    public var openingProgress: Float {
        switch status {
        case .closed: return 0
        case .fullyOpen: return 1
        case .unknown, .partiallyOpen: return angle.isFinite ? min(1, max(0, angle / .pi)) : 0
        }
    }

    /// The hinge's opening from zero to one hundred percent.
    public var openingPercentage: Float { openingProgress * 100 }
}

/// An area reserved by the platform, expressed in the containing window's coordinates.
public struct ViewReservedRegion: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case division
        case occlusion
    }

    public let id: String
    public let kind: Kind
    public let frame: Rect
    public let margins: EdgeInsets
    public let isActive: Bool

    public init(id: String, kind: Kind, frame: Rect, margins: EdgeInsets = EdgeInsets(), isActive: Bool = true) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.margins = margins
        self.isActive = isActive
    }
}

extension EnvironmentValues {
    /// Physical display insets, retained when a descendant expands into the safe area.
    @Entry public var displaySafeAreaInsets: EdgeInsets = EdgeInsets()
    /// The horizontal size class of the containing native window, when available.
    @Entry public var horizontalSizeClass: UserInterfaceSizeClass?
    /// The vertical size class of the containing native window, when available.
    @Entry public var verticalSizeClass: UserInterfaceSizeClass?
    /// Live hinge state for this display, or nil when the display supplies no hinge.
    @Entry public var deviceHinge: DeviceHinge?
    /// Active and inactive platform regions, in window coordinates. Check `isActive` before avoiding a region.
    @Entry public var reservedRegions: [ViewReservedRegion] = []

    /// Where navigation controls are arranged. Automatic follows the available screen edges.
    @Entry public var navigationBarControlsPlacement: NavigationBarControlsPlacement = .automatic
    /// Space occupied by system UI above vertically arranged navigation controls.
    @Entry public var navigationBarControlsTopInset: Float = 0

    /// The axis for custom navigation control groups, including the trailing region on Duo.
    public var navigationBarControlsAxis: Axis {
        resolvedNavigationBarControlsPlacement == .top ? .horizontal : .vertical
    }

    var resolvedNavigationBarControlsPlacement: NavigationBarControlsPlacement {
        guard navigationBarControlsPlacement == .automatic else { return navigationBarControlsPlacement }
        // A substantial side safe area provides the system's vertical control strip.
        // Use its actual edge rather than inferring a display from the phone's model.
        guard userInterfaceIdiom == .phone, max(displaySafeAreaInsets.leading, displaySafeAreaInsets.trailing) >= 60 else { return .top }
        return displaySafeAreaInsets.leading > displaySafeAreaInsets.trailing ? .leading : .trailing
    }

    var unconsumedDisplaySideInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: max(0, displaySafeAreaInsets.leading - safeAreaInsets.leading), bottom: 0,
            trailing: max(0, displaySafeAreaInsets.trailing - safeAreaInsets.trailing))
    }

    /// The side space reserved for navigation and display controls. A layout that
    /// extends into the side strip should keep its content within these insets.
    public var navigationContentSideInsets: EdgeInsets {
        var insets = unconsumedDisplaySideInsets
        switch resolvedNavigationBarControlsPlacement {
        case .leading: insets.leading = max(insets.leading, max(64, displaySafeAreaInsets.leading))
        case .trailing: insets.trailing = max(insets.trailing, max(64, displaySafeAreaInsets.trailing))
        default: break
        }
        return insets
    }
}

public enum NavigationBarControlsPlacement: Hashable, Sendable {
    case automatic
    case top
    case leading
    case trailing
}

extension View {
    /// Overrides automatic placement of navigation controls for this navigation stack.
    public func navigationBarControlsPlacement(_ placement: NavigationBarControlsPlacement) -> some View {
        environment(\.navigationBarControlsPlacement, placement)
    }
}

/// Frames in the workspace's local coordinates; the host has already applied its safe area.
public struct AdaptiveSplitFrames: Equatable, Sendable {
    public let isExpanded: Bool
    public let primary: Rect
    public let secondary: Rect

    public init(size: Size, horizontalSizeClass: UserInterfaceSizeClass?, division: ViewReservedRegion?, minimumPaneWidth: Float = 292) {
        isExpanded = horizontalSizeClass == .regular && size.width >= max(0, minimumPaneWidth) * 2 + 16
        guard isExpanded else {
            primary = .zero
            secondary = Rect(origin: .zero, size: size)
            return
        }
        let division = division.flatMap { $0.isActive ? $0 : nil }
        if let division, division.frame.width > division.frame.height {
            let top = min(size.height, max(0, division.frame.minY - division.margins.top))
            let bottom = min(size.height, max(top, division.frame.maxY + division.margins.bottom))
            primary = Rect(x: 0, y: 0, width: size.width, height: top)
            secondary = Rect(x: 0, y: bottom, width: size.width, height: max(0, size.height - bottom))
        } else {
            let start = division.map { $0.frame.minX - $0.margins.leading } ?? (size.width * 0.5 - 8)
            let end = division.map { $0.frame.maxX + $0.margins.trailing } ?? (size.width * 0.5 + 8)
            let left = min(size.width, max(0, start))
            let right = min(size.width, max(left, end))
            primary = Rect(x: 0, y: 0, width: left, height: size.height)
            secondary = Rect(x: right, y: 0, width: max(0, size.width - right), height: size.height)
        }
    }
}

