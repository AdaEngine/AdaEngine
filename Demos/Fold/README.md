# Fold — Shadow Fold

A native AdaEngine platformer: bend two leaves to turn projected shadows into bridges, then carry a prism from the outer screen into the world.

## Run

Open this folder as a SwiftPM project in AdaEditor and select the **Fold** executable with **Run**. For an embedded preview, open `Sources/FoldGame/FoldGameView.swift` and use its ordinary Swift Preview. The scene editor's generic Play does not install game plugins; Fold owns its runtime.

On macOS, `./script/build_and_run.sh` builds and launches a local `Fold.app`. It uses a separate scratch directory; override `FOLD_BUILD_PATH` to reuse an existing task build. Tests: `swift test --scratch-path /tmp/fold-build`.

## Controls

- Virtual joystick or A / D: move. Space or Jump: jump.
- Angle slider, Q / E, or 180° / 135° / 90°: bend the leaves.
- F / Turn: switch to the outer screen at the last checkpoint.
- Drag the prism into the ring, then T / Transfer. Turn back and bend to approximately 80°.
- R / Reset: restart from the authored initial state.

The first bridge aligns near 135°, the crease crossing near 90°. Checkpoints preserve progress when a shadow disappears. Switching surfaces keeps one world and one prism.

## Ownership

`Sources/FoldGame` owns the pose, projection, physics, game components, plugin, rendering, keyboard handling and scene loader. `Sources/Fold` contains the standalone app. `Assets` contains the level, `.ascn` scene and `.ui` controls; `Director.ada` connects the controls to ECS resources. The AdaScript build plugin embeds the script. `Tests/FoldGameTests` exercises this production loader and full-level completion without importing AdaEditor.

No game-specific registration, Inspector descriptors or Play branches remain in AdaEditor or engine modules. Only reusable display/UI/input APIs remain there.

## Customize the joystick

Fold's `.ui` control is transparent at rest. Its hit area stays in the bottom-left corner; the thumb appears after crossing the dead zone and remains visible until release or cancellation.

```swift
var style = VirtualJoystickStyle.invisibleUntilDragged
style.diameter = 120
style.thumbDiameter = 44
style.movementRadius = 36
style.thumbColor = .fromHex(0x50EACB)
style.activeThumbOpacity = 0.85
// Inside an AdaUI View:
// VirtualJoystick(x: $moveX, y: $moveY, style: style)
```

The same parameters are editable in `Assets/UI/Controls.ui`: `diameter`, `thumbDiameter`, `movementRadius`, `deadZone`, `baseColor`, `ringColor`, `thumbColor`, `ringWidth`, `idleOpacity`, `activeOpacity`, `idleThumbOpacity`, `activeThumbOpacity`. Colors accept RGBA hex strings. Color alpha multiplies opacity. Sizes are logical points; movementRadius is clamped to keep the thumb inside its area. Use idleThumbOpacity = 0 for a hidden idle thumb, and idleOpacity = activeOpacity = 0 for an invisible base. Existing `.ui` files without these fields keep the default style.

## Promo

`Promo/` preserves the earlier prototype's footage, cover and validation captures. They predate this ownership refactor and the transparent joystick; they are historical materials, not recordings of the new build. This is a macOS Foldable Preview, with no claimed hardware sensor or Apple device integration.

## Native lighting

`FoldLightingScene.swift` renders the paper leaves as lit Mesh2D surfaces and places a shadow-casting point Light2D at the active lamp. Physical islands, the current prism and the traveller have LightOccluder2D contours in the same projected coordinates. Fold angle and viewport resizing update the light and contours. The gameplay shadow platforms remain analytically computed colliders and have no turquoise edge; Light2D adds actual rendered shadows from physical objects.
