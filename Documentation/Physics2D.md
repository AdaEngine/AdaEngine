# 2D physics

## Collider transforms

Shape coordinates and offsets are local to the body. A box's `angle` is a
counterclockwise local rotation in radians. Its vertices are rotated first,
then translated by the local offset, then scaled by the entity's scale.
The entity's rotation and position place that geometry in world space:

`worldPoint = bodyPosition + bodyRotation * (entityScale * (shapeRotation * vertex + offset))`

```swift
let shape = Shape2DResource.generateBox(
    width: 4, height: 1, center: [3, 0], angle: .pi / 2
)
```

With entity scale `[2, 1, 1]` this box is centered six units along the body's
local X axis and spans two units along X and four along Y before body rotation.
Polygon vertices and offsets follow the same local scale convention.

`offsetBy(x:y:)` returns a new resource, replacing the existing local offset;
it preserves the shape's other properties, including box rotation.
Circle offsets are scaled too. Circle radius retains the existing X-scale
convention; nonuniform scaling does not create an ellipse. The historical
`generateCircle(radius:)` size convention is unchanged by this compatibility fix.

Existing encoded boxes without `angle` decode as zero local rotation. Older
box data without an offset decodes with a zero offset. Body rotation is applied
on creation for both collision and physics bodies; rotating a static collider
without moving it is synchronized before the next simulation step. Simulated
rotation writes back to `Transform` using the same counterclockwise convention.

## Capsules and rounded convex shapes

The throwing factories `generateCapsule(from:to:radius:)`,
`generateRoundedBox(width:height:radius:center:angle:)` and
`generateRoundedPolygon(vertices:radius:)` reject invalid geometry with
`Shape2DGeometryError`. Decoding these new resource kinds applies the same validation.

Capsule endpoints are the local centers of their semicircular caps. Their
separation must exceed native linear slop (0.005 meters with default units).
The radius is the actual cap radius, independent of the historical circle factory convention.

Rounded-box dimensions include the corner arcs. Its corner radius must be
smaller than half the smaller outer dimension. Rounded-polygon vertices instead
describe a convex core: its radius expands beyond that core. Supply 3...8 convex
points; interior, duplicate and degenerate points are rejected.

Offsets and core vertices follow the local transform convention above.
For capsules and rounded polygons, rounding remains circular: radius is multiplied
by the larger absolute XY scale. Nonuniform scale therefore gives a conservative
round approximation, not an ellipse. Geometry collapsed by entity scale is not
registered as an invalid native shape and does not trip native hull assertions.
