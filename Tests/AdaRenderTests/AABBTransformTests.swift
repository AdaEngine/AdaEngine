import Math
import Testing
@testable import AdaRender

@Suite
struct AABBTransformTests {
    @Test
    func transformedMatchesBruteForceCorners() {
        let aabb = AABB(min: [-1, -2, -3], max: [4, 1, 2])
        let transform = Transform3D(
            translation: [5, -2, 7],
            rotation: Quat(axis: Vector3(0.3, 1, 0.2).normalized, angle: 0.8),
            scale: [2, 0.5, 3]
        )

        var expectedMin = Vector3(Float.greatestFiniteMagnitude)
        var expectedMax = Vector3(-Float.greatestFiniteMagnitude)
        for x in [aabb.min.x, aabb.max.x] {
            for y in [aabb.min.y, aabb.max.y] {
                for z in [aabb.min.z, aabb.max.z] {
                    let corner = (transform * Vector4(x, y, z, 1)).xyz
                    expectedMin = Vector3(min(expectedMin.x, corner.x), min(expectedMin.y, corner.y), min(expectedMin.z, corner.z))
                    expectedMax = Vector3(max(expectedMax.x, corner.x), max(expectedMax.y, corner.y), max(expectedMax.z, corner.z))
                }
            }
        }

        let result = aabb.transformed(by: transform)
        #expect(abs(result.min.x - expectedMin.x) < 1e-3 && abs(result.max.x - expectedMax.x) < 1e-3)
        #expect(abs(result.min.y - expectedMin.y) < 1e-3 && abs(result.max.y - expectedMax.y) < 1e-3)
        #expect(abs(result.min.z - expectedMin.z) < 1e-3 && abs(result.max.z - expectedMax.z) < 1e-3)
    }
}
