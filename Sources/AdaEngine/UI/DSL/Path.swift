//
//  Path.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

import Math

public struct Path {

  private var elements: [Element] = []

  public var isEmpty: Bool {
    return elements.isEmpty
  }

  public var boundingRect: Rect {
    fatalError()
  }

  public enum Element: Equatable {
    case move(to: Vector2)

    case line(to: Vector2)

    case quadCurve(to: Point, control: Point)

    /// A cubic Bézier curve from the previous current point to the given
    /// end-point, using the two control points to define the curve.
    ///
    /// The end-point of the curve becomes the new current point.
    case curve(to: Point, control1: Point, control2: Point)

    /// A line from the start point of the current subpath (if any) to the
    /// current point, which terminates the subpath.
    ///
    /// After closing the subpath, the current point becomes undefined.
    case closeSubpath

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (a: Path.Element, b: Path.Element) -> Bool {
      return false
//      switch (a, b) {
//      case let (.move(to: lhs), .move(to: rhs)):
//        return lhs == rhs
//      }
    }

  }

  public init() {}

  public init(_ callback: (inout Path) -> Void) {
    var path = Path()
    callback(&path)
    self = path
  }

  public func forEach(_ body: (Path.Element) -> Void) {
    self.elements.forEach(body)
  }
}

extension Path {

  /// Begins a new subpath at the specified point.
  ///
  /// The specified point becomes the start point of a new subpath.
  /// The current point is set to this start point.
  ///
  /// - Parameter end: The point, in user space coordinates, at which
  ///   to start a new subpath.
  ///
  public mutating func move(to end: Vector2) {
    self.elements.append(.move(to: end))
  }

  /// Appends a straight line segment from the current point to the
  /// specified point.
  ///
  /// After adding the line segment, the current point is set to the
  /// endpoint of the line segment.
  ///
  /// - Parameter end: The location, in user space coordinates, for the
  ///   end of the new line segment.
  ///
  public mutating func addLine(to end: Vector2) {
    self.elements.append(.line(to: end))
  }

  /// Adds a quadratic Bézier curve to the path, with the
  /// specified end point and control point.
  ///
  /// This method constructs a curve starting from the path's current
  /// point and ending at the specified end point, with curvature
  /// defined by the control point. After this method appends that
  /// curve to the current path, the end point of the curve becomes
  /// the path's current point.
  ///
  /// - Parameters:
  ///     the curve.
  ///   - control: The control point of the curve, in user space
  ///     coordinates.
  ///
  public mutating func addQuadCurve(to end: Point, control: Point) {
    self.elements.append(.quadCurve(to: end, control: control))
  }

  /// Adds a cubic Bézier curve to the path, with the
  /// specified end point and control points.
  ///
  /// This method constructs a curve starting from the path's current
  /// point and ending at the specified end point, with curvature
  /// defined by the two control points. After this method appends
  /// that curve to the current path, the end point of the curve
  /// becomes the path's current point.
  ///
  /// - Parameters:
  ///     the curve.
  ///   - control1: The first control point of the curve, in user
  ///     space coordinates.
  ///   - control2: The second control point of the curve, in user
  ///     space coordinates.
  ///
  public mutating func addCurve(to end: Point, control1: Point, control2: Point) {
    self.elements.append(.curve(to: end, control1: control1, control2: control2))
  }

  /// Closes and completes the current subpath.
  ///
  /// Appends a line from the current point to the starting point of
  /// the current subpath and ends the subpath.
  ///
  /// After closing the subpath, your application can begin a new
  /// subpath without first calling `move(to:)`. In this case, a new
  /// subpath is implicitly created with a starting and current point
  /// equal to the previous subpath's starting point.
  ///
  public mutating func closeSubpath() {
    self.elements.append(.closeSubpath)
  }

  /// Adds a rectangular subpath to the path.
  ///
  /// This is a convenience function that adds a rectangle to a path,
  /// starting by moving to the bottom-left corner and then adding
  /// lines counter-clockwise to create a rectangle, closing the
  /// subpath.
  ///
  /// - Parameters:
  ///   - rect: A rectangle, specified in user space coordinates.
  ///   - transform: An affine transform to apply to the rectangle
  ///     before adding to the path. Defaults to the identity
  ///     transform if not specified.
  ///
  public mutating func addRect(_ rect: Rect, transform: Transform2D = .identity) {

  }

}
