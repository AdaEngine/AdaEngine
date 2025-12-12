//
//  FrustumTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 12.12.2025.
//

import Testing
import AdaUtils
import Math

@Suite("Frustum Tests")
struct FrustumTests {

    // MARK: - Frustum.make(from:) Tests

    @Test("Frustum.make creates valid frustum from orthographic projection")
    func makeFromOrthographicProjection() {
        // Create an orthographic projection matrix
        // left=-5, right=5, top=5, bottom=-5, near=1, far=100
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Verify that all 6 planes are created
        #expect(frustum.planes.count == 6)

        // Test points inside the frustum
        let insideAABB = AABB(center: Vector3(0, 0, 50), halfExtents: Vector3(1, 1, 1))
        #expect(frustum.intersectsAABB(insideAABB), "Center point should be inside frustum")

        // Test point at the center of the frustum volume
        let centerAABB = AABB(center: Vector3(0, 0, 50.5), halfExtents: Vector3(0.1, 0.1, 0.1))
        #expect(frustum.intersectsAABB(centerAABB), "Frustum center should be inside")
    }

    @Test("Frustum.make correctly culls objects outside left boundary")
    func makeFromOrthographicCullsLeft() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object far to the left (outside x = -5 boundary)
        let outsideLeft = AABB(center: Vector3(-10, 0, 50), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideLeft), "Object far left should be culled")
    }

    @Test("Frustum.make correctly culls objects outside right boundary")
    func makeFromOrthographicCullsRight() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object far to the right (outside x = 5 boundary)
        let outsideRight = AABB(center: Vector3(10, 0, 50), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideRight), "Object far right should be culled")
    }

    @Test("Frustum.make correctly culls objects outside top boundary")
    func makeFromOrthographicCullsTop() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object above (outside y = 5 boundary)
        let outsideTop = AABB(center: Vector3(0, 10, 50), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideTop), "Object above should be culled")
    }

    @Test("Frustum.make correctly culls objects outside bottom boundary")
    func makeFromOrthographicCullsBottom() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object below (outside y = -5 boundary)
        let outsideBottom = AABB(center: Vector3(0, -10, 50), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideBottom), "Object below should be culled")
    }

    @Test("Frustum.make correctly culls objects in front of near plane")
    func makeFromOrthographicCullsNear() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object in front of near plane (z < 1)
        let outsideNear = AABB(center: Vector3(0, 0, 0), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideNear), "Object in front of near plane should be culled")
    }

    @Test("Frustum.make correctly culls objects beyond far plane")
    func makeFromOrthographicCullsFar() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object beyond far plane (z > 100)
        let outsideFar = AABB(center: Vector3(0, 0, 150), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideFar), "Object beyond far plane should be culled")
    }

    @Test("Frustum.make from perspective projection works correctly")
    func makeFromPerspectiveProjection() {
        // Create a perspective projection matrix
        let projection = Transform3D.perspective(
            fieldOfView: .degrees(90),
            aspectRatio: 1.0,
            zNear: 0.1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Verify that all 6 planes are created
        #expect(frustum.planes.count == 6)

        // Test point inside the frustum (at z = 10, which is well within near/far)
        let insideAABB = AABB(center: Vector3(0, 0, 10), halfExtents: Vector3(1, 1, 1))
        #expect(frustum.intersectsAABB(insideAABB), "Center point should be inside perspective frustum")
    }

    @Test("Frustum.make perspective correctly culls objects behind camera")
    func makeFromPerspectiveCullsBehind() {
        let projection = Transform3D.perspective(
            fieldOfView: .degrees(90),
            aspectRatio: 1.0,
            zNear: 0.1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object behind camera (negative z)
        let behindCamera = AABB(center: Vector3(0, 0, -10), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(behindCamera), "Object behind camera should be culled")
    }

    @Test("Frustum.make perspective correctly culls objects beyond far plane")
    func makeFromPerspectiveCullsFar() {
        let projection = Transform3D.perspective(
            fieldOfView: .degrees(90),
            aspectRatio: 1.0,
            zNear: 0.1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object beyond far plane
        let beyondFar = AABB(center: Vector3(0, 0, 200), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(beyondFar), "Object beyond far plane should be culled")
    }

    @Test("Frustum.make perspective correctly culls objects outside FOV")
    func makeFromPerspectiveCullsOutsideFOV() {
        let projection = Transform3D.perspective(
            fieldOfView: .degrees(90),
            aspectRatio: 1.0,
            zNear: 0.1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // With 90 degree FOV, at z=10, the visible area is roughly x,y in [-10, 10]
        // An object at x=50 should be well outside
        let outsideFOV = AABB(center: Vector3(50, 0, 10), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideFOV), "Object outside FOV should be culled")
    }

    // MARK: - Frustum.makeWithoutFar Tests

    @Test("Frustum.makeWithoutFar creates frustum with unset far plane")
    func makeWithoutFarTest() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.makeWithoutFar(from: projection)

        // Should still have 6 planes but far plane is default (zero)
        #expect(frustum.planes.count == 6)

        // Far plane (index 5) should be zero/default
        let farPlane = frustum.planes[5]!
        #expect(farPlane.normal == Vector3.zero, "Far plane normal should be zero")
        #expect(farPlane.d == 0, "Far plane d should be zero")

        // Test point inside should work
        let insideAABB = AABB(center: Vector3(0, 0, 50), halfExtents: Vector3(1, 1, 1))
        #expect(frustum.intersectsAABB(insideAABB), "Center point should be inside frustum")

        // Left/right/top/bottom culling should still work
        let outsideLeft = AABB(center: Vector3(-20, 0, 50), halfExtents: Vector3(0.5, 0.5, 0.5))
        #expect(!frustum.intersectsAABB(outsideLeft), "Object outside left should be culled")
    }

    // MARK: - View-Projection Matrix Tests

    @Test("Frustum.make with combined view-projection matrix")
    func makeFromViewProjectionMatrix() {
        // Create view matrix (camera at origin looking at +Z)
        let view = Transform3D.identity

        // Create projection matrix
        let projection = Transform3D.orthographic(
            left: -10,
            right: 10,
            top: 10,
            bottom: -10,
            zNear: 1,
            zFar: 50
        )

        // Combined view-projection
        let viewProjection = projection * view

        let frustum = Frustum.make(from: viewProjection)

        // Test point inside
        let inside = AABB(center: Vector3(0, 0, 25), halfExtents: Vector3(1, 1, 1))
        #expect(frustum.intersectsAABB(inside), "Point should be inside view-projection frustum")

        // Test point outside (too far)
        let outside = AABB(center: Vector3(0, 0, 100), halfExtents: Vector3(1, 1, 1))
        #expect(!frustum.intersectsAABB(outside), "Point should be outside view-projection frustum")
    }

    // MARK: - Edge Cases

    @Test("Object exactly at frustum boundary is visible")
    func objectAtBoundaryIsVisible() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Object straddling the left boundary
        let atLeftBoundary = AABB(center: Vector3(-5, 0, 50), halfExtents: Vector3(1, 1, 1))
        #expect(frustum.intersectsAABB(atLeftBoundary), "Object at boundary should be visible (intersecting)")
    }

    @Test("Zero-size AABB inside frustum is visible")
    func zeroSizeAABBInsideIsVisible() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Point-like AABB inside frustum
        let pointAABB = AABB(center: Vector3(0, 0, 50), halfExtents: Vector3.zero)
        #expect(frustum.intersectsAABB(pointAABB), "Zero-size AABB inside should be visible")
    }

    @Test("Large AABB partially inside is visible")
    func largeAABBPartiallyInsideIsVisible() {
        let projection = Transform3D.orthographic(
            left: -5,
            right: 5,
            top: 5,
            bottom: -5,
            zNear: 1,
            zFar: 100
        )

        let frustum = Frustum.make(from: projection)

        // Large AABB that extends past boundaries but overlaps frustum
        let largeAABB = AABB(center: Vector3(8, 0, 50), halfExtents: Vector3(5, 5, 5))
        #expect(frustum.intersectsAABB(largeAABB), "Large AABB overlapping frustum should be visible")
    }
}
