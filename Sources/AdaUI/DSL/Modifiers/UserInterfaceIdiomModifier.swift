//
//  UserInterfaceIdiomModifier.swift
//  AdaEngine
//

import AdaUtils

/// Constants that indicate the interface type for the device.
public enum UserInterfaceIdiom: Hashable, Sendable, CaseIterable {
    case phone
    case pad
    case xr
    case desktop
    case tv
}

public extension EnvironmentValues {
    @Entry var userInterfaceIdiom: UserInterfaceIdiom = .desktop
}
