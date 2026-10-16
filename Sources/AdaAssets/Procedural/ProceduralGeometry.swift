//
//  ProceduralGeometry.swift
//  AdaEngine
//

#if os(Android)
import Android
#endif
import Foundation

/// CPU mesh data for procedurally generated models. Front faces wind so that `cross(b - a, c - a)` points outward.
public struct ProceduralMeshData: Sendable, Equatable {
    public var positions: [SIMD3<Float>] = []
    public var normals: [SIMD3<Float>] = []
    public var uvs: [SIMD2<Float>] = []
    public var indices: [UInt32] = []

    public init() {}

    public var isEmpty: Bool { indices.isEmpty }
}

/// Generators for the primitive shapes used by procedural models.
///
/// All shapes are centered on the origin with Y up. Revolved shapes share smooth normals along a profile
/// and keep hard edges where adjacent profile segments turn by more than ``creaseAngle``.
public enum ProceduralGeometry {
    /// Profile corners sharper than this (radians) get separate normals.
    public static let creaseAngle: Float = .pi / 3

    public static func box(width: Float, height: Float, depth: Float) -> ProceduralMeshData {
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            ([1, 0, 0], [0, 0, -1], [0, 1, 0]),
            ([-1, 0, 0], [0, 0, 1], [0, 1, 0]),
            ([0, 1, 0], [1, 0, 0], [0, 0, -1]),
            ([0, -1, 0], [1, 0, 0], [0, 0, 1]),
            ([0, 0, 1], [1, 0, 0], [0, 1, 0]),
            ([0, 0, -1], [-1, 0, 0], [0, 1, 0]),
        ]
        let corners: [SIMD2<Float>] = [[-1, -1], [1, -1], [1, 1], [-1, 1]]
        var mesh = ProceduralMeshData()
        let half = SIMD3<Float>(width, height, depth) / 2
        for (normal, horizontal, vertical) in faces {
            let start = UInt32(mesh.positions.count)
            for corner in corners {
                mesh.positions.append((normal + horizontal * corner.x + vertical * corner.y) * half)
                mesh.normals.append(normal)
                mesh.uvs.append(SIMD2((corner.x + 1) / 2, (1 - corner.y) / 2))
            }
            mesh.indices += [start, start + 1, start + 2, start + 2, start + 3, start]
        }
        return mesh
    }

    /// A horizontal plane facing +Y.
    public static func plane(width: Float, depth: Float) -> ProceduralMeshData {
        var mesh = ProceduralMeshData()
        let (x, z) = (width / 2, depth / 2)
        mesh.positions = [[-x, 0, -z], [-x, 0, z], [x, 0, z], [x, 0, -z]]
        mesh.normals = Array(repeating: [0, 1, 0], count: 4)
        mesh.uvs = [[0, 1], [0, 0], [1, 0], [1, 1]]
        mesh.indices = [0, 1, 2, 2, 3, 0]
        return mesh
    }

    public static func sphere(radius: Float, segments: Int) -> ProceduralMeshData {
        let rings = max(segments / 2, 3)
        let profile = (0...rings).map { ring -> SIMD2<Float> in
            let angle = Float.pi * Float(ring) / Float(rings)
            return SIMD2(radius * sin(angle), radius * cos(angle))
        }
        return lathe(profile: profile, segments: segments)
    }

    /// A cylinder, or a cone/frustum when the radii differ. Zero radii give a point.
    public static func cylinder(radiusTop: Float, radiusBottom: Float, height: Float, segments: Int) -> ProceduralMeshData {
        let h = height / 2
        return lathe(profile: [[0, h], [radiusTop, h], [radiusBottom, -h], [0, -h]], segments: segments)
    }

    /// A capsule whose total height includes both hemispheres.
    public static func capsule(radius: Float, height: Float, segments: Int) -> ProceduralMeshData {
        let section = max(height - 2 * radius, 0) / 2
        let steps = max(segments / 4, 2)
        var profile: [SIMD2<Float>] = []
        for step in 0...steps {
            let angle = Float.pi / 2 * Float(step) / Float(steps)
            profile.append(SIMD2(radius * sin(angle), section + radius * cos(angle)))
        }
        for step in 0...steps {
            let angle = Float.pi / 2 + Float.pi / 2 * Float(step) / Float(steps)
            profile.append(SIMD2(radius * sin(angle), -section + radius * cos(angle)))
        }
        return lathe(profile: profile, segments: segments)
    }

    public static func torus(majorRadius: Float, minorRadius: Float, segments: Int) -> ProceduralMeshData {
        let tubeSegments = max(segments / 2, 6)
        var profile = (0..<tubeSegments).map { step -> SIMD2<Float> in
            let angle = 2 * Float.pi * Float(step) / Float(tubeSegments)
            return SIMD2(majorRadius + minorRadius * cos(angle), -minorRadius * sin(angle))
        }
        profile.append(profile[0])
        return lathe(profile: profile, segments: segments)
    }

    /// Revolves a `(radius, y)` profile around the Y axis.
    ///
    /// Order the points so the outside faces to the left of the direction of travel with +radius to the right
    /// and +y up: a solid goes from the top, outward and down the side, then back to the axis at the bottom.
    /// Repeating the first point closes the profile into a ring.
    public static func lathe(profile input: [SIMD2<Float>], segments: Int) -> ProceduralMeshData {
        var points: [SIMD2<Float>] = []
        for point in input where points.last.map({ vecDistance($0, point) > 1e-6 }) ?? true { points.append(point) }
        let closed = points.count > 2 && vecDistance(points[0], points[points.count - 1]) < 1e-6
        if closed { points.removeLast() }
        let segmentCount = closed ? points.count : points.count - 1
        guard segmentCount >= 1, segments >= 3 else { return ProceduralMeshData() }

        let normals = (0..<segmentCount).map { index -> SIMD2<Float> in
            let direction = vecNormalize(points[(index + 1) % points.count] - points[index])
            return SIMD2(-direction.y, direction.x)
        }
        var lengths: [Float] = [0]
        for index in 0..<segmentCount { lengths.append(lengths[index] + vecDistance(points[(index + 1) % points.count], points[index])) }
        let total = max(lengths[segmentCount], 1e-6)

        func joined(_ normal: SIMD2<Float>, _ neighbor: SIMD2<Float>?) -> SIMD2<Float> {
            guard let neighbor, vecDot(normal, neighbor) > cos(creaseAngle) else { return normal }
            return vecNormalize(normal + neighbor)
        }
        var mesh = ProceduralMeshData()
        for index in 0..<segmentCount {
            let previous = index > 0 ? normals[index - 1] : (closed ? normals[segmentCount - 1] : nil)
            let next = index + 1 < segmentCount ? normals[index + 1] : (closed ? normals[0] : nil)
            let ends = [
                (points[index], joined(normals[index], previous), lengths[index]),
                (points[(index + 1) % points.count], joined(normals[index], next), lengths[index + 1]),
            ]
            for (point, normal, length) in ends {
                for step in 0...segments {
                    let angle = 2 * Float.pi * Float(step) / Float(segments)
                    mesh.positions.append(SIMD3(point.x * cos(angle), point.y, point.x * sin(angle)))
                    mesh.normals.append(SIMD3(normal.x * cos(angle), normal.y, normal.x * sin(angle)))
                    mesh.uvs.append(SIMD2(Float(step) / Float(segments), 1 - length / total))
                }
            }
            let start = UInt32(index * 2 * (segments + 1))
            let end = start + UInt32(segments + 1)
            for step in 0..<UInt32(segments) {
                // Quad corners: a/d on the start ring, b/c on the end ring, d and c one step further around.
                let (a, d, b, c) = (start + step, start + step + 1, end + step, end + step + 1)
                if points[index].x > 1e-6 || points[(index + 1) % points.count].x > 1e-6 {
                    if points[(index + 1) % points.count].x > 1e-6 { mesh.indices += [a, c, b] }
                    if points[index].x > 1e-6 { mesh.indices += [a, d, c] }
                }
            }
        }
        return mesh
    }

    /// Flat-shaded mesh from explicit triangles, wound counter-clockwise when seen from outside.
    /// Degenerate triangles are skipped.
    public static func flat(vertices: [SIMD3<Float>], triangles: [SIMD3<Int>]) -> ProceduralMeshData {
        var mesh = ProceduralMeshData()
        for triangle in triangles {
            let (a, b, c) = (vertices[triangle.x], vertices[triangle.y], vertices[triangle.z])
            let cross = vecCross(b - a, c - a)
            guard vecLength(cross) > 1e-9 else { continue }
            let normal = vecNormalize(cross)
            let axis = abs(normal.x) > abs(normal.y) && abs(normal.x) > abs(normal.z) ? 0 : (abs(normal.y) > abs(normal.z) ? 1 : 2)
            let start = UInt32(mesh.positions.count)
            for point in [a, b, c] {
                mesh.positions.append(point)
                mesh.normals.append(normal)
                mesh.uvs.append(axis == 0 ? SIMD2(point.z, point.y) : (axis == 1 ? SIMD2(point.x, point.z) : SIMD2(point.x, point.y)))
            }
            mesh.indices += [start, start + 1, start + 2]
        }
        return mesh
    }
}
