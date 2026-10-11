import AdaEngine
import Foundation
import Math

/// Navigation changes the tracking-space placement, never authored scene transforms.
@MainActor
final class EditorVRNavigationController {
    private struct Zoom {
        let interactors: Set<SpatialInteractor>
        let forward: Vector3
        var distance: Float
    }
    private var zoom: Zoom?
    private var finishingInteractors: Set<SpatialInteractor> = []
    private var blockedKeys: Set<KeyCode> = []
    var isNavigating: Bool { zoom != nil || !finishingInteractors.isEmpty }

    func reset() {
        zoom = nil
        finishingInteractors.removeAll()
        blockedKeys.removeAll()
    }

    func update(in world: World, keys: Set<KeyCode> = [], wheel: Float = 0, textEditing: Bool = false) -> Vector3 {
        guard let tracking = world.getResource(SpatialTrackingFrame.self), var input = world.getResource(SpatialInput.self) else {
            reset()
            return .zero
        }
        let current = Set(input.grips.map(\.interactor))
        // A remaining held pinch must not acquire an object when the other hand releases.
        if !finishingInteractors.isEmpty {
            finishingInteractors.formIntersection(current)
            input.grips.removeAll { finishingInteractors.contains($0.interactor) }
            world.insertResource(input)
            return .zero
        }
        if var zoom {
            let grips = input.grips.filter { zoom.interactors.contains($0.interactor) }
            input.grips.removeAll { zoom.interactors.contains($0.interactor) }
            world.insertResource(input)
            guard grips.count == 2, let distance = Self.handDistance(grips) else {
                finishingInteractors = zoom.interactors.intersection(current)
                self.zoom = nil
                return .zero
            }
            let amount = min(max(Float(log(Double(distance / zoom.distance))) * 1.5, -0.5), 0.5)
            zoom.distance = distance
            self.zoom = zoom
            return zoom.forward * amount
        }
        if world.getResource(SpatialSelection.self)?.isGrabbed != true,
            input.grips.count == 2, Set(input.grips.map(\.interactor)).count == 2,
            let distance = Self.handDistance(input.grips) {
            let forward = (tracking.head * Vector4(0, 0, 1, 0)).xyz.normalized
            zoom = Zoom(interactors: current, forward: forward, distance: distance)
            input.grips.removeAll()
            world.insertResource(input)
            return .zero
        }
        // Suppress keys held while editing until they are released, including after focus changes.
        blockedKeys.formIntersection(keys)
        if textEditing {
            blockedKeys.formUnion(keys)
            return .zero
        }
        guard world.getResource(SpatialSelection.self)?.isGrabbed != true else {
            return .zero
        }
        let active = keys.subtracting(blockedKeys)
        var forward = (tracking.head * Vector4(0, 0, 1, 0)).xyz
        forward.y = 0
        forward = forward.squaredLength > 0.0001 ? forward.normalized : Vector3(0, 0, 1)
        let right = Vector3(forward.z, 0, -forward.x)
        var movement = Vector3.zero
        if active.contains(.w) { movement += forward }
        if active.contains(.s) { movement -= forward }
        if active.contains(.d) { movement += right }
        if active.contains(.a) { movement -= right }
        let delta = min(max(world.getResource(DeltaTime.self)?.deltaTime ?? 0, 0), 0.05)
        if movement.squaredLength > 0 { movement = movement.normalized * delta * 2 }
        if wheel.isFinite { movement += (tracking.head * Vector4(0, 0, 1, 0)).xyz.normalized * min(max(wheel * 0.15, -1), 1) }
        return movement
    }

    private static func handDistance(_ grips: [SpatialGrip]) -> Float? {
        let distance = (grips[1].pose.origin - grips[0].pose.origin).length
        return distance.isFinite && distance >= 0.04 && distance <= 2 ? distance : nil
    }
}
