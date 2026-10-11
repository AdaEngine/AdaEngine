#if os(visionOS)
    import AdaSpatial
    import ARKit
    import Math
    import QuartzCore
    import simd

    @available(visionOS 26.0, *)
    @MainActor
    final class ImmersiveTracking {
        let session = ARKitSession()
        let world = WorldTrackingProvider()
        private let hands = HandTrackingProvider()
        private var leftPinch = SpatialPinchState()
        private var rightPinch = SpatialPinchState()
        private var tracksHands = false

        func start() async throws {
            guard WorldTrackingProvider.isSupported else { throw ImmersiveRendererError.worldTrackingUnavailable }
            if HandTrackingProvider.isSupported {
                let authorization = await session.requestAuthorization(for: [.handTracking])
                tracksHands = authorization[.handTracking] == .allowed
            }
            var providers: [any DataProvider] = [world]
            if tracksHands { providers.append(hands) }
            try await session.run(providers)
        }

        func stop() {
            session.stop()
            leftPinch = SpatialPinchState()
            rightPinch = SpatialPinchState()
        }

        func grips(at timestamp: Double) -> [SpatialGrip] {
            guard tracksHands, hands.state == .running else {
                leftPinch.update(distance: nil, isTracked: false)
                rightPinch.update(distance: nil, isTracked: false)
                return []
            }
            let anchors = hands.handAnchors(at: timestamp)
            var grips: [SpatialGrip] = []
            if let left = grip(anchors.leftHand, interactor: .leftHand, state: &leftPinch) { grips.append(left) }
            if let right = grip(anchors.rightHand, interactor: .rightHand, state: &rightPinch) { grips.append(right) }
            return grips
        }

        func handPoses(at timestamp: Double) -> [SpatialHandPose] {
            guard tracksHands, hands.state == .running else { return [] }
            let anchors = hands.handAnchors(at: timestamp)
            return [(anchors.leftHand, SpatialInteractor.leftHand), (anchors.rightHand, SpatialInteractor.rightHand)].compactMap { anchor, identity in
                guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else { return nil }
                let wrist = skeleton.joint(.wrist)
                let index = skeleton.joint(.indexFingerKnuckle)
                let little = skeleton.joint(.littleFingerKnuckle)
                let tip = skeleton.joint(.indexFingerTip)
                let middle = skeleton.joint(.middleFingerTip)
                guard wrist.isTracked, index.isTracked, little.isTracked, tip.isTracked, middle.isTracked else { return nil }
                func point(_ joint: HandSkeleton.Joint) -> Vector3 {
                    let matrix = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
                    return SpatialCoordinates.fromApple(Vector3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z))
                }
                let w = point(wrist)
                let i = point(index)
                let l = point(little)
                var pose = SpatialCoordinates.fromApple(Transform3D(anchor.originFromAnchorTransform))
                pose.origin = (w + i + l) / 3
                let normal = (i - w).cross(l - w).normalized
                return SpatialHandPose(interactor: identity, pose: pose, palmNormal: normal,
                    isOpen: (point(tip) - w).length > 0.12 && (point(middle) - w).length > 0.13)
            }
        }

        private func grip(_ anchor: HandAnchor?, interactor: SpatialInteractor, state: inout SpatialPinchState) -> SpatialGrip? {
            guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else {
                state.update(distance: nil, isTracked: false)
                return nil
            }
            let thumb = skeleton.joint(.thumbTip)
            let index = skeleton.joint(.indexFingerTip)
            guard thumb.isTracked, index.isTracked else {
                state.update(distance: nil, isTracked: false)
                return nil
            }
            let thumbPose = anchor.originFromAnchorTransform * thumb.anchorFromJointTransform
            let indexPose = anchor.originFromAnchorTransform * index.anchorFromJointTransform
            let distance = simd_distance(thumbPose.columns.3.xyz, indexPose.columns.3.xyz)
            guard state.update(distance: distance, isTracked: true) else {
                return nil
            }
            var pose = anchor.originFromAnchorTransform
            pose.columns.3 = SIMD4<Float>((thumbPose.columns.3.xyz + indexPose.columns.3.xyz) * 0.5, 1)
            return SpatialGrip(interactor: interactor, pose: SpatialCoordinates.fromApple(Transform3D(pose)))
        }
    }

    extension SIMD4 where Scalar == Float {
        var xyz: SIMD3<Float> { SIMD3(x, y, z) }
    }

    extension Transform3D {
        init(_ matrix: simd_float4x4) {
            self.init(
                Vector4(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w),
                Vector4(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w),
                Vector4(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w),
                Vector4(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w)
            )
        }
    }
#endif
