# Sprite Animation

Sprite animation plays named frame clips on an entity's `Sprite`. The frames live in a shared `.spriteanim` resource, so many entities can use one sheet without copying it. `SpritePlugin`, included by `DefaultPlugins`, registers everything below.

In Studio choose **New File → Resources → Sprite Animation**. Open the `.spriteanim` resource to set the image, author clips, preview playback, and add the animation to an open scene. Edits are written immediately and enter the editor's Undo/Redo history. Reload explicitly if another program changes the file; the editor refuses to overwrite those changes.

## Resource

`.spriteanim` uses YAML on native platforms.

```yaml
version: 1
image: hero.png            # relative to this file
cellSize: {width: 16, height: 16}
filter: nearest            # nearest or linear (default)
clips:
  - name: run
    framesPerSecond: 12    # default 12
    playbackMode: loop     # loop (default), once or pingPong
    frames:
      - {atlasCoordinates: {x: 0, y: 1}}
      - {atlasCoordinates: {x: 1, y: 1}, duration: 2, marker: step}
  - name: slash
    framesPerSecond: 10
    playbackMode: once
    frames:
      - {region: {x: 0, y: 32, width: 24, height: 16}}
```

A frame picks its pixels in one of two ways, and needs exactly one of them:

- `atlasCoordinates` is a cell of the grid defined by `cellSize` (the whole image when omitted).
- `region` is a pixel rectangle from the image's top-left corner. Use it for packed sheets whose frames differ in size.

`duration` scales one frame (default 1, so 2 holds it twice as long). `marker` names an event delivered when the frame appears. The editor and loader reject empty or duplicate clip names, non-positive `framesPerSecond` and frames with neither or both pixel sources; a bad resource fails to load instead of half-loading. A frame outside the image keeps the previous texture.

## Swift

```swift
let animations = try await AssetsManager.load(SpriteAnimationSet.self, at: "@res://Hero/hero.spriteanim", handleChanges: true)
world.spawn("Hero") {
    Transform()
    Sprite(size: Size(width: 32, height: 32))
    SpriteAnimator(animations: animations, initialClip: "run")
}
```

Without `initialClip` the first clip plays. A set can also be built in code with `SpriteAnimationSet(atlas:clips:)` or `SpriteAnimationSet(descriptor:image:)`.

The animator owns `Sprite.texture` while a clip is selected. All controls are plain fields, so scripts and the Inspector use them too:

| Field | Effect |
| --- | --- |
| `currentClip` | Selects a clip and starts it from its first frame. Unknown names are ignored. |
| `isPlaying` | Pause or resume. |
| `speed` | Time multiplier. Negative and non-finite values stop playback. |
| `restartCount` | Increment to replay the selected clip from its first frame. |

`play(_:restart:)`, `pause()` and `stop()` wrap these for Swift code. Selecting the clip that is already current keeps its frame.

### Events

`SpriteAnimationEvent` is delivered through `Events<SpriteAnimationEvent>` with the entity, the clip name and one of `frameChanged(index)`, `marker(name)`, `looped` and `finished` (`once` clips only). Several can arrive in one frame when a long step crosses frames; they arrive in playback order.

```swift
@PlainSystem
struct HitFrames {
    @EventsReader<SpriteAnimationEvent> private var events
    func update(context _: UpdateContext) {
        for event in events where event.kind == .marker("hit") { /* apply damage */ }
    }
}
```

## AdaScript

```
@system class Hero {
    @query(SpriteAnimator) var heroes;
    func update(context) {
        for (var entity in heroes) {
            entity.spriteAnimator.currentClip = "jump";
        }
    }
}
```

`SpriteAnimator(animations: set, initialClip: "idle", speed: 1.5)` accepts a `SpriteAnimationSet` loaded with `Assets.preload`. A script that also constructs a `Sprite` needs it registered with the script runtime; Studio does this, and plain engine hosts must call `RuntimeTypeRegistry.registerComponent(Sprite.self, …)` first.

## Aseprite

Export with **File → Export Sprite Sheet**, choose the JSON Data output in the **Array** layout, and leave **Trim** and **Rotation** off, then keep the JSON and PNG together. In the Sprite Animation editor enter the JSON path (relative to the `.spriteanim`) under **Import from Aseprite** and press **Import**. The image and clips are replaced in one undoable edit.

- Each frame tag becomes a clip. A sheet without tags becomes one `default` clip.
- Frame durations (milliseconds) are converted to a shared step: 100 ms frames become 10 fps with duration 1, while a mix of 100/300 ms becomes 10 fps with durations 1 and 3.
- `forward` and `reverse` become `loop` (reverse reverses the frame order); `pingpong` becomes `pingPong`; a tag with `repeat: 1` becomes `once`.
- The Hash layout is accepted when frames are named with a trailing number (`hero 12`), because JSON objects have no order.
- Trimmed or rotated frames are rejected with a message instead of being shown misplaced.

From Swift use `AsepriteSheet(data:)`, then `descriptor(imagePath:)` to get a `SpriteAnimationSetDescriptor`.

## Validation

All of these run against the real systems, not mocks:

```sh
swift test --filter "SpriteAnimation|AsepriteImport|AdaScriptSpriteAnimation"
```

covers the playback rules, the system in a real world with real textures and events, `.spriteanim` loading through the asset manager, Aseprite parsing, and an AdaScript that constructs and drives an animator. The GPU check draws each frame through the production extraction, batching and draw pass and reads pixels back, in both the instanced and the batched sprite path; run it alone in a fresh process:

```sh
ADAENGINE_SPRITE_ANIM_METAL_SMOKE=1 swift test --filter SpriteAnimationMetalTests
```

The editor tests (`Editor/`, Xcode toolchain, see its README) cover authoring, persistence, Aseprite import, Add to Scene and scene loading.
