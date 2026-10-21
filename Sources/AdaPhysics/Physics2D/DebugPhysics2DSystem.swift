//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

import AdaCorePipelines
import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import AdaUtils
import box2d
import Math

public struct PhysicsDebugOptions: OptionSet, Resource {
    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// Draw physics collision shapes for physics object.
    public static let showPhysicsShapes = Self(rawValue: 1 << 0)

    public static let showBoundingBoxes = Self(rawValue: 1 << 1)
    /// Draw native 2D joint frames, limits and support connections.
    public static let showJoints = Self(rawValue: 1 << 2)
}

// MARK: - Extracted Debug Shapes

/// Contains extracted debug shapes for rendering.
public struct ExtractedPhysicsDebugShapes: Resource {
    public var lines: [DebugLine] = []
    public var circles: [DebugCircle] = []

    public struct DebugLine: Sendable {
        public let start: Vector2
        public let end: Vector2
        public let color: Color
    }

    public struct DebugCircle: Sendable {
        public let center: Vector2
        public let radius: Float
        public let color: Color
    }
}

// MARK: - Draw Data Resources

/// A data for drawing physics debug shapes.
public struct PhysicsDebugDrawData: Resource, DefaultValue {
    public var lineVertexBuffer: BufferData<LineVertexData>
    public var lineIndexBuffer: BufferData<UInt32>
    public var circleVertexBuffer: BufferData<CircleVertexData>
    public var circleIndexBuffer: BufferData<UInt32>

    public static let defaultValue: PhysicsDebugDrawData = {
        Self(
            lineVertexBuffer: .init(label: "PhysicsDebug_LineVertexBuffer", elements: []),
            lineIndexBuffer: .init(label: "PhysicsDebug_LineIndexBuffer", elements: []),
            circleVertexBuffer: .init(label: "PhysicsDebug_CircleVertexBuffer", elements: []),
            circleIndexBuffer: .init(label: "PhysicsDebug_CircleIndexBuffer", elements: [])
        )
    }()
}

/// Batches for physics debug rendering.
public struct PhysicsDebugBatches: Resource {
    public struct LineBatch: Sendable {
        public var range: Range<Int32>
    }

    public struct CircleBatch: Sendable {
        public var range: Range<Int32>
    }

    public var lineBatch: LineBatch?
    public var circleBatch: CircleBatch?

    public init() {}
}

// MARK: - Debug Draw Context

/// Context for collecting debug draw calls from Box2D.
private final class WorldDebugDrawContext {
    var lines: [ExtractedPhysicsDebugShapes.DebugLine] = []
    var circles: [ExtractedPhysicsDebugShapes.DebugCircle] = []

    func addLine(start: Vector2, end: Vector2, color: Color) {
        self.lines.append(.init(start: start, end: end, color: color))
    }

    func addCircle(center: Vector2, radius: Float, color: Color) {
        self.circles.append(.init(center: center, radius: radius, color: color))
    }

    func clear() {
        lines.removeAll(keepingCapacity: true)
        circles.removeAll(keepingCapacity: true)
    }
}

// MARK: - Box2D Debug Draw Callbacks

private func DebugPhysicsExctract2DSystem_DrawSolidCircle(
    _ transform: b2WorldTransform,
    _ localCenter: b2Vec2,
    _ radius: Float,
    _ color: b2HexColor,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else {
        return
    }
    let debugContext = unsafe Unmanaged<WorldDebugDrawContext>
        .fromOpaque(context)
        .takeUnretainedValue()

    let color = Color.fromHex(Int(color.rawValue))

    let center = b2TransformPoint(transform, localCenter).asVector2

    debugContext.addCircle(center: center, radius: radius, color: color)

    // Draw direction indicator line
    let direction = Vector2(
        transform.q.c * radius,  // cos(angle) * radius
        transform.q.s * radius  // sin(angle) * radius
    )

    let start = center
    let end = center + direction

    debugContext.addLine(start: start, end: end, color: color)
}

private func DebugPhysicsExctract2DSystem_DrawSolidPolygon(
    _ transform: b2WorldTransform,
    _ vertices: UnsafePointer<b2Vec2>?,
    _ vertexCount: Int32,
    _ radius: Float,
    _ color: b2HexColor,
    _ context: UnsafeMutableRawPointer?
) {
    guard let vertices = unsafe vertices, let context = unsafe context, vertexCount >= 3 else {
        return
    }
    let output = unsafe Unmanaged<WorldDebugDrawContext>.fromOpaque(context).takeUnretainedValue()
    let color = Color.fromHex(Int(color.rawValue))
    let count = Int(vertexCount)
    for index in 0..<count {
        let point = unsafe vertices[index].asVector2
        let next = unsafe vertices[(index + 1) % count].asVector2
        var normal = Vector2.zero
        if radius > 0 {
            let edge = next - point
            normal = Vector2(edge.y, -edge.x) / edge.squaredLength.squareRoot()
        }
        output.addLine(
            start: b2TransformPoint(transform, (point + normal * radius).b2Vec).asVector2,
            end: b2TransformPoint(transform, (next + normal * radius).b2Vec).asVector2,
            color: color
        )
        if radius > 0 {
            let previous = unsafe vertices[(index + count - 1) % count].asVector2
            let edge = point - previous
            let initial = Math.atan2(-edge.x, edge.y)
            var angle = Math.atan2(normal.y, normal.x) - initial
            if angle < 0 { angle += 2 * .pi }
            for step in 0..<8 {
                let a = initial + angle * Float(step) / 8
                let b = initial + angle * Float(step + 1) / 8
                let start = point + Vector2(Math.cos(a), Math.sin(a)) * radius
                let end = point + Vector2(Math.cos(b), Math.sin(b)) * radius
                output.addLine(
                    start: b2TransformPoint(transform, start.b2Vec).asVector2,
                    end: b2TransformPoint(transform, end.b2Vec).asVector2,
                    color: color
                )
            }
        }
    }
}

private func DebugPhysics2D_Polygon(_ transform: b2WorldTransform, _ vertices: UnsafePointer<b2Vec2>?, _ count: Int32, _ color: b2HexColor, _ context: UnsafeMutableRawPointer?) {
    unsafe DebugPhysicsExctract2DSystem_DrawSolidPolygon(transform, vertices, count, 0, color, context)
}

private func DebugPhysics2D_Line(_ start: b2Pos, _ end: b2Pos, _ color: b2HexColor, _ context: UnsafeMutableRawPointer?) {
    guard let context = unsafe context else {
        return
    }
    let output = unsafe Unmanaged<WorldDebugDrawContext>.fromOpaque(context).takeUnretainedValue()
    output.addLine(start: start.asVector2, end: end.asVector2, color: Color.fromHex(Int(color.rawValue)))
}

private func DebugPhysics2D_Circle(_ center: b2Pos, _ radius: Float, _ color: b2HexColor, _ context: UnsafeMutableRawPointer?) {
    guard let context = unsafe context else {
        return
    }
    let output = unsafe Unmanaged<WorldDebugDrawContext>.fromOpaque(context).takeUnretainedValue()
    output.addCircle(center: center.asVector2, radius: radius, color: Color.fromHex(Int(color.rawValue)))
}

private func DebugPhysics2D_Point(_ center: b2Pos, _ size: Float, _ color: b2HexColor, _ context: UnsafeMutableRawPointer?) {
    let radius = max(0.025, min(0.12, size * 0.005))
    unsafe DebugPhysics2D_Line(b2Pos(x: center.x - radius, y: center.y), b2Pos(x: center.x + radius, y: center.y), color, context)
    unsafe DebugPhysics2D_Line(b2Pos(x: center.x, y: center.y - radius), b2Pos(x: center.x, y: center.y + radius), color, context)
}

private func DebugPhysics2D_Capsule(_ start: b2Pos, _ end: b2Pos, _ radius: Float, _ color: b2HexColor, _ context: UnsafeMutableRawPointer?) {
    guard let context = unsafe context else {
        return
    }
    let output = unsafe Unmanaged<WorldDebugDrawContext>.fromOpaque(context).takeUnretainedValue()
    var shapes = ExtractedPhysicsDebugShapes()
    swap(&shapes.lines, &output.lines)
    swap(&shapes.circles, &output.circles)
    shapes.addCapsule(from: start.asVector2, to: end.asVector2, radius: radius, color: Color.fromHex(Int(color.rawValue)))
    swap(&shapes.lines, &output.lines)
    swap(&shapes.circles, &output.circles)
}

@MainActor
extension PhysicsWorld2D {
    func collectDebugShapes(options: PhysicsDebugOptions) -> ExtractedPhysicsDebugShapes {
        guard options.contains(.showPhysicsShapes) || options.contains(.showJoints) else {
            return ExtractedPhysicsDebugShapes()
        }
        let context = WorldDebugDrawContext()
        var draw = unsafe b2DefaultDebugDraw()
        unsafe draw.DrawSolidPolygonFcn = DebugPhysicsExctract2DSystem_DrawSolidPolygon
        unsafe draw.DrawPolygonFcn = DebugPhysics2D_Polygon
        unsafe draw.DrawSolidCircleFcn = DebugPhysicsExctract2DSystem_DrawSolidCircle
        unsafe draw.DrawCircleFcn = DebugPhysics2D_Circle
        unsafe draw.DrawSolidCapsuleFcn = DebugPhysics2D_Capsule
        unsafe draw.DrawLineFcn = DebugPhysics2D_Line
        unsafe draw.DrawPointFcn = DebugPhysics2D_Point
        unsafe draw.context = Unmanaged.passUnretained(context).toOpaque()
        unsafe draw.drawShapes = options.contains(.showPhysicsShapes)
        unsafe draw.drawJoints = options.contains(.showJoints)
        unsafe draw.drawJointExtras = options.contains(.showJoints)
        unsafe debugDraw(with: draw)
        var shapes = ExtractedPhysicsDebugShapes()
        shapes.lines = context.lines
        shapes.circles = context.circles
        return shapes
    }
}

// MARK: - Extract System

/// System for extracting physics bodies for debug rendering.
@System
@MainActor
public func ExtractPhysicsDebug(
    _ extractedShapes: ResMut<ExtractedPhysicsDebugShapes>,
    _ debugOptions: Extract<Res<PhysicsDebugOptions>>,
    _ physicsWorld: Extract<
        Res<Physics2DWorldHolder>
    >
) {
    extractedShapes.wrappedValue = physicsWorld().world.collectDebugShapes(options: debugOptions().wrappedValue)
}

// MARK: - Prepare System

/// System for preparing physics debug render items.
@PlainSystem
public struct PreparePhysicsDebugSystem: Sendable {
    @ResMut<RenderItems<Transparent2DRenderItem>>
    private var renderItems

    @ResMut
    private var linePipeline: RenderPipelines<LinePipeline>

    @ResMut
    private var circlePipeline: RenderPipelines<CirclePipeline>

    @Res
    private var renderDevice: RenderDeviceHandler

    @Res<ExtractedPhysicsDebugShapes>
    private var extractedShapes

    @Res
    private var lineDrawPass: PhysicsDebugLineDrawPass

    @Res
    private var circleDrawPass: PhysicsDebugCircleDrawPass

    public init(world _: World) {}

    public func update(context _: UpdateContext) {
        // Skip if no shapes to render
        if extractedShapes.lines.isEmpty && extractedShapes.circles.isEmpty {
            return
        }

        // Add line render item if we have lines
        if !extractedShapes.lines.isEmpty {
            let pipeline = linePipeline.pipeline(device: renderDevice.renderDevice)

            renderItems.items.append(
                Transparent2DRenderItem(
                    entity: 0,
                    drawPass: lineDrawPass,
                    renderPipeline: pipeline,
                    sortKey: .greatestFiniteMagnitude,  // Render on top
                    batchRange: 0..<Int32(extractedShapes.lines.count)
                )
            )
        }

        // Add circle render item if we have circles
        if !extractedShapes.circles.isEmpty {
            let pipeline = circlePipeline.pipeline(device: renderDevice.renderDevice)

            renderItems.items.append(
                Transparent2DRenderItem(
                    entity: 0,
                    drawPass: circleDrawPass,
                    renderPipeline: pipeline,
                    sortKey: .greatestFiniteMagnitude,  // Render on top
                    batchRange: 0..<Int32(extractedShapes.circles.count)
                )
            )
        }
    }
}

// MARK: - Render System

/// System for tessellating and batching physics debug shapes.
@PlainSystem
public struct PhysicsDebugRenderSystem: Sendable {
    /// Quad corner positions for circle SDF rendering.
    private let quadPositions: [Vector4] = [
        [-0.5, -0.5, 0.0, 1.0],
        [0.5, -0.5, 0.0, 1.0],
        [0.5, 0.5, 0.0, 1.0],
        [-0.5, 0.5, 0.0, 1.0],
    ]

    @Res<ExtractedPhysicsDebugShapes>
    private var extractedShapes

    @ResMut<PhysicsDebugDrawData>
    private var drawData

    @ResMut<PhysicsDebugBatches>
    private var batches

    @Res<RenderDeviceHandler>
    private var renderDevice

    public init(world _: World) {}

    public func update(context _: UpdateContext) {
        // Clear previous frame data
        drawData.lineVertexBuffer.elements.removeAll(keepingCapacity: true)
        drawData.lineIndexBuffer.elements.removeAll(keepingCapacity: true)
        drawData.circleVertexBuffer.elements.removeAll(keepingCapacity: true)
        drawData.circleIndexBuffer.elements.removeAll(keepingCapacity: true)
        batches.lineBatch = nil
        batches.circleBatch = nil

        let device = renderDevice.renderDevice

        // Tessellate lines
        if !extractedShapes.lines.isEmpty {
            let lineCount = extractedShapes.lines.count

            for line in extractedShapes.lines {
                let vertexOffset = UInt32(drawData.lineVertexBuffer.count)

                // Add line vertices
                drawData.lineVertexBuffer.append(
                    LineVertexData(
                        position: Vector3(line.start.x, line.start.y, 0),
                        color: line.color,
                        lineWidth: 2.0
                    )
                )
                drawData.lineVertexBuffer.append(
                    LineVertexData(
                        position: Vector3(line.end.x, line.end.y, 0),
                        color: line.color,
                        lineWidth: 2.0
                    )
                )

                // Add line indices
                drawData.lineIndexBuffer.append(vertexOffset)
                drawData.lineIndexBuffer.append(vertexOffset + 1)
            }

            batches.lineBatch = .init(range: 0..<Int32(lineCount))

            drawData.lineVertexBuffer.write(to: device)
            drawData.lineIndexBuffer.write(to: device)
        }

        // Tessellate circles
        if !extractedShapes.circles.isEmpty {
            let circleCount = extractedShapes.circles.count

            for circle in extractedShapes.circles {
                let vertexOffset = UInt32(drawData.circleVertexBuffer.count)

                // Create a transform for the circle
                let scale = circle.radius * 2.0
                let transform = Transform3D(
                    translation: Vector3(circle.center.x, circle.center.y, 0),
                    rotation: .identity,
                    scale: Vector3(scale, scale, 1.0)
                )

                // Tessellate circle into 4 vertices (SDF rendering)
                for quadPos in quadPositions {
                    let worldPos = transform * quadPos
                    let localPos = quadPos * 2  // Scale to [-1, 1] range for SDF

                    drawData.circleVertexBuffer.append(
                        CircleVertexData(
                            worldPosition: worldPos.xyz,
                            localPosition: Vector2(localPos.x, localPos.y),
                            thickness: 0.05,  // Stroke thickness
                            fade: 0.01,  // Anti-aliasing fade
                            color: circle.color
                        )
                    )
                }

                // Add circle indices (2 triangles forming a quad)
                drawData.circleIndexBuffer.append(vertexOffset + 0)
                drawData.circleIndexBuffer.append(vertexOffset + 1)
                drawData.circleIndexBuffer.append(vertexOffset + 2)
                drawData.circleIndexBuffer.append(vertexOffset + 2)
                drawData.circleIndexBuffer.append(vertexOffset + 3)
                drawData.circleIndexBuffer.append(vertexOffset + 0)
            }

            batches.circleBatch = .init(range: 0..<Int32(circleCount))

            drawData.circleVertexBuffer.write(to: device)
            drawData.circleIndexBuffer.write(to: device)
        }
    }
}

// MARK: - Draw Passes

/// Draw pass for rendering physics debug lines.
public struct PhysicsDebugLineDrawPass: DrawPass, Resource {
    public typealias Item = Transparent2DRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view _: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard
            let drawData = world.getResource(PhysicsDebugDrawData.self),
            let batches = world.getResource(PhysicsDebugBatches.self),
            let batch = batches.lineBatch
        else {
            return
        }

        guard !drawData.lineVertexBuffer.isEmpty else {
            return
        }

        renderEncoder.pushDebugName("PhysicsDebugLineDrawPass")
        defer {
            renderEncoder.popDebugName()
        }

        renderEncoder.setVertexBuffer(drawData.lineVertexBuffer, offset: 0, slot: 0)
        renderEncoder.setIndexBuffer(drawData.lineIndexBuffer, indexFormat: .uInt32)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        let lineCount = Int(batch.range.upperBound - batch.range.lowerBound)
        renderEncoder.drawIndexed(
            indexCount: lineCount * 2,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}

/// Draw pass for rendering physics debug circles.
public struct PhysicsDebugCircleDrawPass: DrawPass, Resource {
    public typealias Item = Transparent2DRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view _: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard
            let drawData = world.getResource(PhysicsDebugDrawData.self),
            let batches = world.getResource(PhysicsDebugBatches.self),
            let batch = batches.circleBatch
        else {
            return
        }

        guard !drawData.circleVertexBuffer.isEmpty else {
            return
        }

        renderEncoder.pushDebugName("PhysicsDebugCircleDrawPass")
        defer {
            renderEncoder.popDebugName()
        }

        renderEncoder.setVertexBuffer(drawData.circleVertexBuffer, offset: 0, slot: 0)
        renderEncoder.setIndexBuffer(drawData.circleIndexBuffer, indexFormat: .uInt32)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        let circleCount = Int(batch.range.upperBound - batch.range.lowerBound)
        renderEncoder.drawIndexed(
            indexCount: circleCount * 6,  // 6 indices per circle quad
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}
