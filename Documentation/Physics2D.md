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

## Segments and chains

`generateSegment(from:to:)` creates a two-sided zero-thickness collider.
`generateChain(points:isLoop:ghostStart:ghostEnd:)` creates an owned one-sided
chain; `generateChainSegment(from:to:ghostStart:ghostEnd:)` creates a loose
one-sided segment. The front face lies on the right of each directed edge:
write horizontal floor points from right to left to face upward. Closed loops
must not repeat their first vertex. Ghosts default to linear extrapolation on
open endpoints. Degenerate, duplicate and intersecting chain geometry is rejected.

Offsets/scales are applied to points and ghosts. Mirrored entity scale reverses
the sequence to preserve the authored front side. Native chains have zero mass
and are intended for static terrain. They inherit material, filters and event
flags; all child segments are destroyed with the owning body. A sensor chain
uses body-owned loose sensor segments because native chain definitions cannot
set `isSensor`. Compound/chain events and query hits remain per shape pair;
several segments belonging to one entity can produce several hits.

## Overlap queries

Call the main-actor methods `world.overlap(at:)` for point containment,
`world.overlap(in:)` for broad-phase Rect/AABB candidates, and
`world.overlap(shape, at: transform)` for exact convex-shape overlap.
The shape overload accepts circles, capsules, boxes, rounded/ordinary convex
polygons and two-sided segments; chains are not convex query volumes and throw
`Physics2DQueryError.unsupportedShape`. Invalid poses/geometry throw typed errors;
invalid point or rectangle inputs return no hits. Query transforms follow the
same local geometry, scale and body rotation convention as collider creation.

Masks select shape categories (and native symmetric query filtering still
applies). Sensors are included by default; use `includeSensors: false` to omit
them, and `excluding: [entity.id]` to exclude an entity's complete compound shape.
`Overlap2DHit` is per shape, sorted by entity ID then shape ID. Its `shapeID` is
an ephemeral native identifier within this world, not a persistent asset ID.
Callers needing unique entities can deduplicate by entity ID explicitly.

### Convex sweeps

`try world.shapeCast(shape, from: pose, to: destination, query: .first)` sweeps
one convex volume at fixed rotation and scale. `.all` returns every native
shape hit in travel-distance order; `.first` clips at the closest accepted hit.
The distance measures movement of the pose origin, not distance to the surface.
The same masks, sensor option and entity exclusions apply as in overlap queries.
Initial overlaps have fraction/distance zero and a zero normal; zero motion uses
exact overlap. Chains can be targets but cannot be swept as query volumes.
Thin boxes use analytic vertices so hull welding does not discard them.

### Distance and rope joints

Attach `PhysicsJoint2DComponent(joint: descriptor)` to a joint-owner entity (no
Transform is required). `try PhysicsJoint2DDescriptor.distance(entityA:entityB:settings:)`
connects two entities in the same world. `DistanceJoint2DSettings` supports rigid
rest length, optional spring, lower/upper distance limits and a bounded motor.
`JointFrame2D` anchors are body-local physical coordinates, independent of entity
scale. Spring frequency is in Hz, damping ratio is dimensionless, length/speed
use world length units, motor effort is force.

The legacy `rope(entityA:entityB:)` factory now creates a real cable whose maximum
length is measured when both bodies first resolve; it allows slack. Body creation
can be deferred. Read `isConnected` and `jointError` on the component for status.
Replacing `jointDescriptor` reconnects at the next physics sync. Removing the
owner/component/body releases the constraint; a recreated body reconnects on the
next sync. Runtime records do not keep bodies or worlds alive, and native world
destruction releases all remaining constraints. New distance factories and decoded
settings reject nonfinite/invalid values before native calls.
