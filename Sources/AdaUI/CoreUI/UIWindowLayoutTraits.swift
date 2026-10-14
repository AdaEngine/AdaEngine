/// Live platform geometry included in UI inspection and MCP window snapshots.
public struct UIWindowLayoutTraits: Codable, Hashable, Sendable {
    public let horizontalSizeClass: UserInterfaceSizeClass?
    public let verticalSizeClass: UserInterfaceSizeClass?
    public let safeAreaInsets: EdgeInsets
    public let navigationControlsTopInset: Float
    public let hinge: DeviceHinge?
    public let reservedRegions: [ViewReservedRegion]

    public init(horizontalSizeClass: UserInterfaceSizeClass?, verticalSizeClass: UserInterfaceSizeClass?, safeAreaInsets: EdgeInsets,
        navigationControlsTopInset: Float, hinge: DeviceHinge?, reservedRegions: [ViewReservedRegion]) {
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.safeAreaInsets = safeAreaInsets
        self.navigationControlsTopInset = navigationControlsTopInset
        self.hinge = hinge
        self.reservedRegions = reservedRegions
    }
}
