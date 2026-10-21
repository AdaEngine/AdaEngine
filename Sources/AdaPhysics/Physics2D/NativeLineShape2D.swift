import AdaTransform
import box2d
import Math

extension BoxShape2D {
    static func makeLine(
        _ resource: Shape2DResource.LineShape,
        kind: Geometry2DValidation.LineKind,
        transform: Transform,
        definition: b2ShapeDef,
        body: b2BodyId
    ) -> b2ShapeId {
        let scale = transform.scale.xy
        var points = resource.points.map { ($0 + resource.offset) * scale }
        var leading = (resource.leadingGhost + resource.offset) * scale
        var trailing = (resource.trailingGhost + resource.offset) * scale
        if kind != .segment && scale.x * scale.y < 0 {
            points.reverse()
            swap(&leading, &trailing)
        }
        let line = Shape2DResource.LineShape(points: points, isLoop: resource.isLoop, ghostStart: leading, ghostEnd: trailing)
        guard (try? Geometry2DValidation.line(line, kind: kind)) != nil else {
            return b2_nullShapeId
        }
        if kind == .segment {
            var segment = b2Segment(point1: points[0].b2Vec, point2: points[1].b2Vec)
            return unsafe withUnsafePointer(to: definition) { unsafe b2CreateSegmentShape(body, $0, &segment) }
        }
        if kind == .loose || (unsafe definition.isSensor) {
            // Native chains cannot be sensors; sensor chains use body-owned loose segments.
            var first = b2_nullShapeId
            let count = line.isLoop ? points.count : points.count - 1
            for index in 0..<count {
                let before = line.isLoop ? points[(index + count - 1) % count] : (index == 0 ? leading : points[index - 1])
                let after = line.isLoop ? points[(index + 2) % count] : (index == count - 1 ? trailing : points[index + 2])
                var segment = b2ChainSegment(
                    ghost1: before.b2Vec,
                    segment: b2Segment(point1: points[index].b2Vec, point2: points[(index + 1) % points.count].b2Vec),
                    ghost2: after.b2Vec,
                    chainId: 0
                )
                let id = unsafe withUnsafePointer(to: definition) { unsafe b2CreateChainSegmentShape(body, $0, &segment) }
                if index == 0 { first = id }
            }
            return first
        }
        let native = points.map(\.b2Vec)
        let chainID = unsafe native.withUnsafeBufferPointer { buffer in
            unsafe withUnsafePointer(to: definition.material) { material in
                var chain = unsafe b2DefaultChainDef()
                unsafe chain.points = buffer.baseAddress
                unsafe chain.pointCount = Int32(buffer.count)
                unsafe chain.isLoop = line.isLoop
                unsafe chain.ghost1 = leading.b2Vec
                unsafe chain.ghost2 = trailing.b2Vec
                unsafe chain.materials = material
                unsafe chain.materialCount = 1
                unsafe chain.filter = definition.filter
                unsafe chain.enableSensorEvents = definition.enableSensorEvents
                unsafe chain.userData = definition.userData
                return unsafe b2CreateChain(body, &chain)
            }
        }
        guard b2Chain_IsValid(chainID) else {
            return b2_nullShapeId
        }
        var segments = [b2ShapeId](repeating: b2_nullShapeId, count: Int(b2Chain_GetSegmentCount(chainID)))
        _ = unsafe segments.withUnsafeMutableBufferPointer { unsafe b2Chain_GetSegments(chainID, $0.baseAddress, Int32($0.count)) }
        for segment in segments {
            unsafe b2Shape_EnableContactEvents(segment, definition.enableContactEvents)
            unsafe b2Shape_EnableHitEvents(segment, definition.enableHitEvents)
            unsafe b2Shape_EnablePreSolveEvents(segment, definition.enablePreSolveEvents)
        }
        return segments.first ?? b2_nullShapeId
    }
}
