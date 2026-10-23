# Camera 2D

`Camera2DController` drives a 2D camera: it follows entities, keeps the target in a dead zone, smooths, holds the view inside level limits, zooms, shakes and snaps to pixels. `DefaultPlugins` installs `Camera2DControllerPlugin`, which registers it together with `CameraTarget2D`. When composing plugins by hand, add it after `TransformPlugin`: the controller runs after transform propagation and needs those systems. Studio runs it while a scene plays; the editing camera is the editor's own.

In Studio add **Camera 2D Controller** to a camera entity and **Camera Target 2D** to the entity it should follow.

```swift
world.spawn("Player") {
    Transform()
    Sprite()
    CameraTarget2D(group: "players")
}
world.spawn("Camera") {
    Camera2D()                        // the existing orthographic camera bundle
    Camera2DController(targetGroup: "players", smoothingTime: 0.15, zoom: 2)
}
```

Keep the camera at the scene root. The controller owns the camera's XY position, and its Z rotation while roll shake is on, so move the camera with `position` or `snap(to:)` and not through its `Transform`.

## Following

- **Targets.** Every `CameraTarget2D` whose `group` equals the controller's `targetGroup` counts, weighted by `weight` (zero and negative weights are ignored). Two players with weights 1 and 3 put the camera three quarters of the way to the second one. A camera with no target keeps its `position`; the first update adopts the camera's own `Transform` as the start.
- **`offset`** shifts the followed point in world units, for example to show more of what lies ahead.
- **`smoothingTime`** is the time to cover about 63% of the remaining distance. It gives the same result at 60 and at 10 frames per second. Zero follows instantly.
- **`deadZone`** is the width and height of a box around the camera centre in which the target can move without moving the camera. Past its edge the camera moves just far enough to keep the target on it.
- **`snapCount`**: increment it to jump to the target at once (a teleport or a level change). `snap(to:)` does the same for a camera with no target.

### No lag

The controller runs after transform propagation and publishes the camera's transform and view data itself (`CameraSystem.refreshView`). The frame is therefore extracted with the camera on the target's final position of that frame. A camera that was updated at the start of the frame would trail its target by one frame, which shows as jitter whenever the frame time varies. Visibility culling still uses the camera from the start of the frame, so anything that enters the screen edge can appear one frame late at very high camera speeds.

## Limits

With `limitsEnabled`, the visible area stays inside `limitMin` ... `limitMax` (world units). It accounts for zoom and for a viewport origin that is not centred. If the visible area is larger than the limits on an axis, the camera is centred on the limits for that axis. The limits constrain the stored position, so the camera comes back as soon as the target does.

## Zoom

`zoom` is the orthographic scale: 2 shows half the world area, 0.5 twice as much. It is clamped to `minZoom` ... `maxZoom`. `zoomSmoothingTime` smooths it the same way as following; `visibleZoom` is what is currently shown.

## Shake

`trauma` is the strength from 0 to 1, raised with `addTrauma(_:)` (hits add up to 1) and reduced by `traumaDecay` per second. The shown shake is trauma squared, so small hits are subtle and large ones violent. `shakeMaxOffset` is the largest displacement in world units, `shakeMaxRoll` the largest roll in degrees (zero leaves the camera's rotation alone) and `shakeFrequency` the speed. The shake is a fixed function of time, so it is reproducible, and it sits on top of the followed position without feeding back into it.

## Pixel snapping

`snapsToPixels` rounds the final position to whole screen pixels at the current zoom, which stops pixel art from shimmering while the camera glides. It is applied before the shake.

## AdaScript

All settings are plain fields:

```
@system class Hero {
    @query(Camera2DController) var cameras;
    func update(context) {
        for (var entity in cameras) {
            entity.camera2DController.trauma = 0.75;      // shake
            entity.camera2DController.zoom = 3;
            entity.camera2DController.targetGroup = "boss";
        }
    }
}
```

`Camera2DController(targetGroup:smoothingTime:zoom:)` and `CameraTarget2D(group:weight:)` are available as constructors.

## Validation

```sh
swift test --filter "Camera2D"
```

runs the rules directly (smoothing, dead zone, limits, shake, snapping), the controller in a real world with the real transform and camera systems (including the same-frame check), and an AdaScript that builds and drives a camera. The GPU check draws a scene through the camera's own view uniform and reads pixels back: the followed sprite stays at the centre in the frame it moved, spacing follows zoom, limits pin the view to the level corner and shake moves the picture. Run it alone in a fresh process:

```sh
ADAENGINE_CAMERA2D_METAL_SMOKE=1 swift test --filter Camera2DMetalTests
```
