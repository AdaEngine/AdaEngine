//
//  AnchorPoint.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

/// An opaque value derived from an anchor source and a particular view.
public struct AnchorPoint : Hashable, Sendable {
    /// The x-coordinate of the anchor point.
    public var x: Float = 0

    /// The y-coordinate of the anchor point.
    public var y: Float = 0

    /// Initialize a new anchor point.
    ///
    /// - Returns: The anchor point.
    public init() { }

    /// Initialize a new anchor point.
    ///
    /// - Parameter x: The x-coordinate of the anchor point.
    /// - Parameter y: The y-coordinate of the anchor point.
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    /// The zero anchor point.
    public static let zero = AnchorPoint(x: 0.0, y: 0.0)

    /// The center anchor point.
    public static let center = AnchorPoint(x: 0.5, y: 0.5)

    /// The leading anchor point.
    public static let leading = AnchorPoint(x: 0.0, y: 0.5)

    public static let trailing = AnchorPoint(x: 1.0, y: 0.5)

    /// The top anchor point.
    public static let top = AnchorPoint(x: 0.5, y: 0.0)

    /// The bottom anchor point.
    public static let bottom = AnchorPoint(x: 0.5, y: 1.0)

    /// The top leading anchor point.
    public static let topLeading = AnchorPoint(x: 0.0, y: 0.0)

    /// The top trailing anchor point.
    public static let topTrailing = AnchorPoint(x: 1.0, y: 0.0)

    /// The bottom leading anchor point.
    public static let bottomLeading = AnchorPoint(x: 0.0, y: 1.0)

    /// The bottom trailing anchor point.
    public static let bottomTrailing = AnchorPoint(x: 1.0, y: 1.0)
}
