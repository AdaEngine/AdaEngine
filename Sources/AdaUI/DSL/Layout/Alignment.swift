//
//  Alignment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

public enum HorizontalAlignment: Sendable {
    case leading
    case trailing
    case center
}

public enum VerticalAlignment: Sendable {
    case top
    case bottom
    case center
}

public struct Axis: OptionSet, Sendable {
    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let horizontal = Axis(rawValue: 1 << 0)
    public static let vertical = Axis(rawValue: 1 << 1)
}
