//
//  Alignment.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

/// A horizontal alignment.
public enum HorizontalAlignment: Sendable {
    /// The leading alignment.
    case leading
    /// The trailing alignment.
    case trailing
    /// The center alignment.
    case center
}

/// A vertical alignment.
public enum VerticalAlignment: Sendable {
    /// The top alignment.
    case top
    /// The bottom alignment.
    case bottom
    /// The center alignment.
    case center
}

/// A set of axes.
public struct Axis: OptionSet, Sendable {
    /// The raw value of the axis.
    public var rawValue: UInt8

    /// Initialize a new axis.
    ///
    /// - Parameter rawValue: The raw value of the axis.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// The horizontal axis.
    public static let horizontal = Axis(rawValue: 1 << 0)

    /// The vertical axis.
    public static let vertical = Axis(rawValue: 1 << 1)
}
