# Box2D playground

Five interactive AdaEngine scenes, using the same physics systems as games:

- **Raycasts:** a scanning ray, distance-ordered white hit markers, nearest/all
  selection and a blue-only collision mask. The orange block is on another layer.
- **Collisions & sensors:** an orange box bounces on a floor while a blue box
  crosses a green sensor without a physical response. Live counters distinguish
  solid contacts, sensor enter/exit and impact events delivered through ECS.
  “Drop box again” repeats the impact.

- **Geometry & queries:** capsule, rounded box/polygon, segment, open/closed chains
  and a loose chain segment. A white capsule sweeps or overlaps the colored
  colliders; area mode draws broad-phase candidates. Toggle sensor inclusion,
  layer mask, nearest/all and animation. The outlines follow native geometry.

- **Mechanisms:** a 3x3 grid of rope, hinge, slider, weld, suspension wheel,
  pose/velocity motor, pair filter, mover and pogo rigs. Reverse live motors,
  overload the rope to emit a break event, and repair the connections. Pogo is
  experimental in upstream Box2D 3.2.
- **Characters:** left/stop/right, jump, reset and query/dynamic mode controls.
  The query capsule is virtual; the native dynamic capsule pushes the orange
  crate. A moving platform and ramp exercise support and slope behavior.

On macOS run `./Demos/Physics2D/script/build_and_run.sh`. Use `--verify` to launch
all scenes, exercise query/character/motor controls, check live event counters and
save real GPU frames plus `verification.json` in `Demos/Physics2D/dist/proof/`.

Verification also checks both jumps, physical crate movement, native collider
cleanup after a mode switch, repair, and scene re-entry. GPU frames include
`geometry-cast.png`, `geometry-area.png`, `mechanisms.png`,
`character-query.png`, and `character-dynamic.png`.

Deterministic simulation without a window:

```sh
swift run --scratch-path /tmp/adaengine-box2d-3.2-build Physics2DDemo --validate
```

## Query and event semantics

`raycast(from:to:)` casts a finite segment and returns distance-sorted hits.
`.first` means nearest. Invalid/zero-length input and misses return an empty
array. Initial overlaps are ignored. `raycast(from: Ray, maxDistance:)` uses
its origin and normalized XY direction; the default range is 10,000 world units.
Masks select shape categories; the native Box2D query filter also applies.

`CollisionEvents.Began` / `.Ended` include `isSensor`; for sensors `entityA`
is the sensor and the impulse is zero. `.Hit` contains the impact point, normal,
approach speed and the contact's total normal impulse for the current step.
Native shape pairs produce separate events, including compound bodies.
End events whose entities/shapes have already been destroyed are skipped.
A fast visitor swept through a sensor emits begin in that step and end in the next.

Subscribe through `world.subscribe(to:)` for immediate delivery. `Events<T>`
receives the same events through the world-local ECS buffer on the next frame.
The physics plugin installs the event lifecycle if it has not already been set up.
