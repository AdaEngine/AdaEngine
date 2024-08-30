//
//  AnchorPoint.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

public struct AnchorPoint : Hashable, Sendable {
    public var x: Float = 0
    public var y: Float = 0

    public init() { }

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public static let zero = AnchorPoint(x: 0.0, y: 0.0)
    public static let center = AnchorPoint(x: 0.5, y: 0.5)
    public static let leading = AnchorPoint(x: 0.0, y: 0.5)
    public static let trailing = AnchorPoint(x: 1.0, y: 0.5)
    public static let top = AnchorPoint(x: 0.5, y: 0.0)
    public static let bottom = AnchorPoint(x: 0.5, y: 1.0)

    public static let topLeading = AnchorPoint(x: 0.0, y: 0.0)
    public static let topTrailing = AnchorPoint(x: 1.0, y: 0.0)
    public static let bottomLeading = AnchorPoint(x: 0.0, y: 1.0)
    public static let bottomTrailing = AnchorPoint(x: 1.0, y: 1.0)
}
