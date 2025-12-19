//
//  UITessellator.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaRender
import AdaText
import AdaUtils
import AdaCorePipelines
import Math

/// Tessellator for converting UI draw commands into vertex and index data.
public struct UITessellator {

    /// Quad corner positions in local space (centered at origin).
    public static let quadPositions: [Vector4] = [
        [-0.5, -0.5, 0.0, 1.0],
        [ 0.5, -0.5, 0.0, 1.0],
        [ 0.5,  0.5, 0.0, 1.0],
        [-0.5,  0.5, 0.0, 1.0]
    ]

    /// Default texture coordinates for a quad.
    public static let defaultTextureCoords: [Vector2] = [
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 1.0],
        [0.0, 1.0]
    ]

    /// Number of segments for Bezier curve tessellation.
    public static let curveSegments: Int = 16

    public init() {}

    // MARK: - Quad Tessellation

    /// Tessellates a quad into 4 vertices.
    /// - Parameters:
    ///   - transform: The transformation matrix for the quad.
    ///   - texture: Optional texture for the quad.
    ///   - color: Color of the quad.
    ///   - textureIndex: Index into the texture array.
    /// - Returns: Array of 4 quad vertices.
    public func tessellateQuad(
        transform: Transform3D,
        texture: Texture2D?,
        color: Color,
        textureIndex: Int
    ) -> [QuadVertexData] {
        let textureCoords = texture?.textureCoordinates ?? Self.defaultTextureCoords

        return Self.quadPositions.enumerated().map { index, quadPos in
            QuadVertexData(
                position: transform * quadPos,
                color: color,
                textureCoordinate: textureCoords[index],
                textureIndex: textureIndex
            )
        }
    }

    /// Generates 6 indices for a quad starting at the given vertex offset.
    /// - Parameter vertexOffset: The starting vertex index.
    /// - Returns: Array of 6 indices forming 2 triangles.
    public func generateQuadIndices(vertexOffset: UInt32) -> [UInt32] {
        return [
            vertexOffset + 0,
            vertexOffset + 1,
            vertexOffset + 2,
            vertexOffset + 2,
            vertexOffset + 3,
            vertexOffset + 0
        ]
    }

    // MARK: - Circle Tessellation

    /// Tessellates a circle into 4 vertices (rendered using SDF in fragment shader).
    /// - Parameters:
    ///   - transform: The transformation matrix for the circle.
    ///   - thickness: Stroke thickness of the circle.
    ///   - fade: Anti-aliasing fade value.
    ///   - color: Color of the circle.
    /// - Returns: Array of 4 circle vertices.
    public func tessellateCircle(
        transform: Transform3D,
        thickness: Float,
        fade: Float,
        color: Color
    ) -> [CircleVertexData] {
        return Self.quadPositions.map { quadPos in
            let worldPos = transform * quadPos
            let localPos = quadPos * 2  // Scale to [-1, 1] range for SDF

            return CircleVertexData(
                worldPosition: worldPos.xyz,
                localPosition: Vector2(localPos.x, localPos.y),
                thickness: thickness,
                fade: fade,
                color: color
            )
        }
    }

    /// Generates 6 indices for a circle quad starting at the given vertex offset.
    /// - Parameter vertexOffset: The starting vertex index.
    /// - Returns: Array of 6 indices forming 2 triangles.
    public func generateCircleIndices(vertexOffset: UInt32) -> [UInt32] {
        return generateQuadIndices(vertexOffset: vertexOffset)
    }

    // MARK: - Line Tessellation

    /// Tessellates a line into 2 vertices.
    /// - Parameters:
    ///   - start: Start position of the line.
    ///   - end: End position of the line.
    ///   - lineWidth: Width of the line.
    ///   - color: Color of the line.
    /// - Returns: Array of 2 line vertices.
    public func tessellateLine(
        start: Vector3,
        end: Vector3,
        lineWidth: Float,
        color: Color
    ) -> [LineVertexData] {
        return [
            LineVertexData(position: start, color: color, lineWidth: lineWidth),
            LineVertexData(position: end, color: color, lineWidth: lineWidth)
        ]
    }

    /// Generates 2 indices for a line starting at the given vertex offset.
    /// - Parameter vertexOffset: The starting vertex index.
    /// - Returns: Array of 2 indices.
    public func generateLineIndices(vertexOffset: UInt32) -> [UInt32] {
        return [vertexOffset, vertexOffset + 1]
    }

    // MARK: - Glyph Tessellation

    /// Tessellates a glyph into 4 vertices.
    /// - Parameters:
    ///   - glyph: The glyph to tessellate.
    ///   - transform: The transformation matrix.
    ///   - textureIndex: Index into the font atlas array.
    /// - Returns: Array of 4 glyph vertices.
    public func tessellateGlyph(
        _ glyph: Glyph,
        transform: Transform3D,
        textureIndex: Int
    ) -> [GlyphVertexData] {
        let foregroundColor = glyph.attributes.foregroundColor
        let outlineColor = glyph.attributes.outlineColor
        let texCoord = glyph.textureCoordinates

        // Glyph position: [x: pl, y: pb, z: pr, w: pt]
        let pos = glyph.position

        return [
            GlyphVertexData(
                position: transform * Vector4(x: pos.z, y: pos.y, z: 0, w: 1),
                foregroundColor: foregroundColor,
                outlineColor: outlineColor,
                textureCoordinate: Vector2(texCoord.z, texCoord.y),
                textureIndex: textureIndex
            ),
            GlyphVertexData(
                position: transform * Vector4(x: pos.z, y: pos.w, z: 0, w: 1),
                foregroundColor: foregroundColor,
                outlineColor: outlineColor,
                textureCoordinate: Vector2(texCoord.z, texCoord.w),
                textureIndex: textureIndex
            ),
            GlyphVertexData(
                position: transform * Vector4(x: pos.x, y: pos.w, z: 0, w: 1),
                foregroundColor: foregroundColor,
                outlineColor: outlineColor,
                textureCoordinate: Vector2(texCoord.x, texCoord.w),
                textureIndex: textureIndex
            ),
            GlyphVertexData(
                position: transform * Vector4(x: pos.x, y: pos.y, z: 0, w: 1),
                foregroundColor: foregroundColor,
                outlineColor: outlineColor,
                textureCoordinate: Vector2(texCoord.x, texCoord.y),
                textureIndex: textureIndex
            )
        ]
    }

    /// Generates 6 indices for a glyph quad starting at the given vertex offset.
    /// - Parameter vertexOffset: The starting vertex index.
    /// - Returns: Array of 6 indices forming 2 triangles.
    public func generateGlyphIndices(vertexOffset: UInt32) -> [UInt32] {
        return generateQuadIndices(vertexOffset: vertexOffset)
    }

    // MARK: - Path Tessellation

    /// Tessellates a path into line vertices.
    /// Bezier curves are approximated with line segments.
    /// - Parameters:
    ///   - path: The path to tessellate.
    ///   - lineWidth: Width of the path stroke.
    ///   - color: Color of the path.
    ///   - transform: The transformation matrix.
    /// - Returns: Tuple of vertices and indices for lines.
    public func tessellatePath(
        _ path: Path,
        lineWidth: Float,
        color: Color,
        transform: Transform3D
    ) -> (vertices: [LineVertexData], indices: [UInt32]) {
        var vertices: [LineVertexData] = []
        var indices: [UInt32] = []

        var currentPoint: Vector2?
        var subpathStart: Vector2?

        path.forEach { element in
            switch element {
            case let .move(to: point):
                currentPoint = point
                subpathStart = point

            case let .line(to: end):
                guard let start = currentPoint else { break }

                let startWorld = transform * Vector4(start.x, start.y, 0, 1)
                let endWorld = transform * Vector4(end.x, end.y, 0, 1)

                let vertexOffset = UInt32(vertices.count)
                vertices.append(contentsOf: tessellateLine(
                    start: startWorld.xyz,
                    end: endWorld.xyz,
                    lineWidth: lineWidth,
                    color: color
                ))
                indices.append(contentsOf: generateLineIndices(vertexOffset: vertexOffset))

                currentPoint = end

            case let .quadCurve(to: end, control: control):
                guard let start = currentPoint else { break }

                // Tessellate quadratic Bezier curve
                let curveVertices = tessellateQuadraticBezier(
                    start: start,
                    control: control,
                    end: end,
                    segments: Self.curveSegments,
                    lineWidth: lineWidth,
                    color: color,
                    transform: transform
                )

                let vertexOffset = UInt32(vertices.count)
                vertices.append(contentsOf: curveVertices.vertices)
                indices.append(contentsOf: curveVertices.indices.map { $0 + vertexOffset })

                currentPoint = end

            case let .curve(to: end, control1: control1, control2: control2):
                guard let start = currentPoint else { break }

                // Tessellate cubic Bezier curve
                let curveVertices = tessellateCubicBezier(
                    start: start,
                    control1: control1,
                    control2: control2,
                    end: end,
                    segments: Self.curveSegments,
                    lineWidth: lineWidth,
                    color: color,
                    transform: transform
                )

                let vertexOffset = UInt32(vertices.count)
                vertices.append(contentsOf: curveVertices.vertices)
                indices.append(contentsOf: curveVertices.indices.map { $0 + vertexOffset })

                currentPoint = end

            case .closeSubpath:
                guard let start = currentPoint, let subStart = subpathStart else { break }

                let startWorld = transform * Vector4(start.x, start.y, 0, 1)
                let endWorld = transform * Vector4(subStart.x, subStart.y, 0, 1)

                let vertexOffset = UInt32(vertices.count)
                vertices.append(contentsOf: tessellateLine(
                    start: startWorld.xyz,
                    end: endWorld.xyz,
                    lineWidth: lineWidth,
                    color: color
                ))
                indices.append(contentsOf: generateLineIndices(vertexOffset: vertexOffset))

                currentPoint = nil
                subpathStart = nil
            }
        }

        return (vertices, indices)
    }

    // MARK: - Bezier Curve Helpers

    private func tessellateQuadraticBezier(
        start: Vector2,
        control: Vector2,
        end: Vector2,
        segments: Int,
        lineWidth: Float,
        color: Color,
        transform: Transform3D
    ) -> (vertices: [LineVertexData], indices: [UInt32]) {
        var vertices: [LineVertexData] = []
        var indices: [UInt32] = []

        var previousPoint = start

        for i in 1...segments {
            let t = Float(i) / Float(segments)

            // Quadratic Bezier: B(t) = (1-t)^2 * P0 + 2*(1-t)*t * P1 + t^2 * P2
            let oneMinusT = 1 - t
            let point = oneMinusT * oneMinusT * start +
                        2 * oneMinusT * t * control +
                        t * t * end

            let startWorld = transform * Vector4(previousPoint.x, previousPoint.y, 0, 1)
            let endWorld = transform * Vector4(point.x, point.y, 0, 1)

            let vertexOffset = UInt32(vertices.count)
            vertices.append(contentsOf: tessellateLine(
                start: startWorld.xyz,
                end: endWorld.xyz,
                lineWidth: lineWidth,
                color: color
            ))
            indices.append(contentsOf: generateLineIndices(vertexOffset: vertexOffset))

            previousPoint = point
        }

        return (vertices, indices)
    }

    private func tessellateCubicBezier(
        start: Vector2,
        control1: Vector2,
        control2: Vector2,
        end: Vector2,
        segments: Int,
        lineWidth: Float,
        color: Color,
        transform: Transform3D
    ) -> (vertices: [LineVertexData], indices: [UInt32]) {
        var vertices: [LineVertexData] = []
        var indices: [UInt32] = []

        var previousPoint = start

        for i in 1...segments {
            let t = Float(i) / Float(segments)

            // Cubic Bezier: B(t) = (1-t)^3 * P0 + 3*(1-t)^2*t * P1 + 3*(1-t)*t^2 * P2 + t^3 * P3
            let oneMinusT = 1 - t
            let oneMinusT2 = oneMinusT * oneMinusT
            let oneMinusT3 = oneMinusT2 * oneMinusT
            let t2 = t * t
            let t3 = t2 * t

            let point = oneMinusT3 * start +
                        3 * oneMinusT2 * t * control1 +
                        3 * oneMinusT * t2 * control2 +
                        t3 * end

            let startWorld = transform * Vector4(previousPoint.x, previousPoint.y, 0, 1)
            let endWorld = transform * Vector4(point.x, point.y, 0, 1)

            let vertexOffset = UInt32(vertices.count)
            vertices.append(contentsOf: tessellateLine(
                start: startWorld.xyz,
                end: endWorld.xyz,
                lineWidth: lineWidth,
                color: color
            ))
            indices.append(contentsOf: generateLineIndices(vertexOffset: vertexOffset))

            previousPoint = point
        }

        return (vertices, indices)
    }
}
