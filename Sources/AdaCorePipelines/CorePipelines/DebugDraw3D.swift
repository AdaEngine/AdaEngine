import AdaECS
import AdaRender
import AdaUtils
import Math
import Synchronization

/// Immediate-mode 3D debug drawing for gameplay and tooling code.
///
/// Insert-free: ``Core3DPlugin`` registers one shared instance as a main-world resource. Call the drawing
/// methods from any system; each shape lives for `duration` rendered frames (default one) and is then
/// dropped, so a system that draws every frame needs no cleanup. Shapes are depth tested against the 3D
/// scene unless `depthTested` is `false`, in which case they draw on top.
///
/// The queue is bounded by ``maximumLineCount``; lines beyond it are counted in ``droppedLineCount``
/// instead of growing memory without limit.
public final class DebugDraw3D: Resource, Sendable {
    /// One world-space line segment.
    public struct Line: Sendable, Equatable {
        public var start: Vector3
        public var end: Vector3
        public var color: Color
        public var depthTested: Bool
    }

    private struct Entry {
        var line: Line
        var remainingFrames: Int
    }

    private struct State {
        var entries: [Entry] = []
        var dropped = 0
    }

    private let state = Mutex(State())

    /// Hard cap on queued line segments.
    public let maximumLineCount: Int

    public init(maximumLineCount: Int = 200_000) {
        self.maximumLineCount = max(0, maximumLineCount)
    }

    /// Number of line segments currently queued.
    public var lineCount: Int { state.withLock { $0.entries.count } }

    /// Line segments rejected because the queue was full, since the last ``clear()``.
    public var droppedLineCount: Int { state.withLock { $0.dropped } }

    /// Removes every queued shape and resets ``droppedLineCount``.
    public func clear() {
        state.withLock {
            $0.entries.removeAll(keepingCapacity: true)
            $0.dropped = 0
        }
    }

    // MARK: - Shapes

    /// Draws a segment between two world-space points.
    public func line(from start: Vector3, to end: Vector3, color: Color = .white, duration: Int = 1, depthTested: Bool = true) {
        guard start.isFinite, end.isFinite else {
            return
        }
        append([Line(start: start, end: end, color: color, depthTested: depthTested)], duration: duration)
    }

    /// Draws connected segments through `points`, optionally closing the loop.
    public func polyline(_ points: [Vector3], closed: Bool = false, color: Color = .white, duration: Int = 1, depthTested: Bool = true) {
        guard points.count >= 2 else {
            return
        }
        var lines: [Line] = []
        lines.reserveCapacity(points.count)
        for index in 0..<(points.count - 1) {
            lines.append(Line(start: points[index], end: points[index + 1], color: color, depthTested: depthTested))
        }
        if closed, points.count > 2, let first = points.first, let last = points.last {
            lines.append(Line(start: last, end: first, color: color, depthTested: depthTested))
        }
        append(lines.filter { $0.start.isFinite && $0.end.isFinite }, duration: duration)
    }

    /// Draws an oriented box of `halfExtents` in the local space of `transform`.
    public func box(transform: Transform3D = .identity, halfExtents: Vector3, color: Color = .white, duration: Int = 1, depthTested: Bool = true) {
        let corners = Self.boxCorners(halfExtents: halfExtents).map { (transform * Vector4($0, 1)).xyz }
        append(Self.boxEdges(corners: corners, color: color, depthTested: depthTested), duration: duration)
    }

    /// Draws an axis-aligned bounding box.
    public func aabb(_ bounds: AABB, color: Color = .white, duration: Int = 1, depthTested: Bool = true) {
        box(transform: Transform3D(translation: bounds.center, rotation: .identity, scale: .one), halfExtents: bounds.halfExtents, color: color, duration: duration, depthTested: depthTested)
    }

    /// Draws three orthogonal circles that outline a sphere.
    public func sphere(center: Vector3, radius: Float, segments: Int = 24, color: Color = .white, duration: Int = 1, depthTested: Bool = true) {
        guard radius.isFinite, radius > 0, center.isFinite else {
            return
        }
        let count = min(max(segments, 3), 128)
        var lines: [Line] = []
        lines.reserveCapacity(count * 3)
        for (axisA, axisB) in [(Vector3.right, Vector3.up), (Vector3.right, Vector3(0, 0, 1)), (Vector3.up, Vector3(0, 0, 1))] {
            for index in 0..<count {
                let current = Float(index) / Float(count) * 2 * .pi
                let next = Float(index + 1) / Float(count) * 2 * .pi
                lines.append(Line(
                    start: center + axisA * (Math.cos(current) * radius) + axisB * (Math.sin(current) * radius),
                    end: center + axisA * (Math.cos(next) * radius) + axisB * (Math.sin(next) * radius),
                    color: color,
                    depthTested: depthTested
                ))
            }
        }
        append(lines, duration: duration)
    }

    /// Draws the local X (red), Y (green) and Z (blue) axes of `transform`.
    public func axes(transform: Transform3D, length: Float = 1, duration: Int = 1, depthTested: Bool = true) {
        let origin = (transform * Vector4(0, 0, 0, 1)).xyz
        for (direction, color) in [(Vector3.right, Color.red), (Vector3.up, Color.green), (Vector3(0, 0, 1), Color.blue)] {
            line(from: origin, to: (transform * Vector4(direction * length, 1)).xyz, color: color, duration: duration, depthTested: depthTested)
        }
    }

    /// Draws the volume that `viewProjection` maps to normalized device coordinates (depth `0...1`).
    public func frustum(viewProjection: Transform3D, color: Color = .white, duration: Int = 1, depthTested: Bool = true) {
        let inverse = viewProjection.inverse
        var corners: [Vector3] = []
        for z: Float in [0, 1] {
            for (x, y) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
                let point = inverse * Vector4(x, y, z, 1)
                guard point.w.isFinite, abs(point.w) > 1e-8 else {
                    return
                }
                corners.append(point.xyz / point.w)
            }
        }
        // `boxEdges` expects the near face first and the far face second, in matching order.
        append(Self.boxEdges(corners: corners, color: color, depthTested: depthTested), duration: duration)
    }

    // MARK: - Frame handoff

    /// Returns every queued line for this frame and ages the queue: shapes whose duration ends are removed.
    func drainFrame() -> [Line] {
        state.withLock { state in
            let lines = state.entries.map(\.line)
            var kept: [Entry] = []
            kept.reserveCapacity(state.entries.count)
            for var entry in state.entries {
                entry.remainingFrames -= 1
                if entry.remainingFrames > 0 {
                    kept.append(entry)
                }
            }
            state.entries = kept
            return lines
        }
    }

    private func append(_ lines: [Line], duration: Int) {
        let frames = max(1, duration)
        state.withLock { state in
            let room = max(0, maximumLineCount - state.entries.count)
            state.entries.append(contentsOf: lines.prefix(room).map { Entry(line: $0, remainingFrames: frames) })
            state.dropped += max(0, lines.count - room)
        }
    }

    private static func boxCorners(halfExtents: Vector3) -> [Vector3] {
        [
            Vector3(-halfExtents.x, -halfExtents.y, -halfExtents.z), Vector3(halfExtents.x, -halfExtents.y, -halfExtents.z),
            Vector3(halfExtents.x, halfExtents.y, -halfExtents.z), Vector3(-halfExtents.x, halfExtents.y, -halfExtents.z),
            Vector3(-halfExtents.x, -halfExtents.y, halfExtents.z), Vector3(halfExtents.x, -halfExtents.y, halfExtents.z),
            Vector3(halfExtents.x, halfExtents.y, halfExtents.z), Vector3(-halfExtents.x, halfExtents.y, halfExtents.z),
        ]
    }

    /// Twelve edges of eight corners ordered as two quads (indices 0...3 and 4...7) in matching winding.
    private static func boxEdges(corners: [Vector3], color: Color, depthTested: Bool) -> [Line] {
        guard corners.count == 8, corners.allSatisfy(\.isFinite) else {
            return []
        }
        let edges = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]
        return edges.map { Line(start: corners[$0.0], end: corners[$0.1], color: color, depthTested: depthTested) }
    }
}

private extension Vector3 {
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

/// The lines of the frame being rendered, copied from ``DebugDraw3D`` during extraction.
public struct ExtractedDebugLines3D: Resource, Sendable {
    public var lines: [DebugDraw3D.Line] = []

    public init() {}

    /// Whether a pass draws on the output after the last color writer, so earlier passes must not yet
    /// report the output as ready to present.
    var hasOverlay: Bool { !lines.isEmpty }
}

@System
public func ExtractDebugDraw3D(
    _ source: Extract<Res<DebugDraw3D>>,
    _ extracted: ResMut<ExtractedDebugLines3D>
) {
    extracted.lines = source().wrappedValue.drainFrame()
}
