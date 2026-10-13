# Unfold the world

An adaptive-layout regression fixture. One scene keeps running as a second display region reveals an interactive mission map.

## Validation

`EditorFoldableTests` supplies compact and expanded display regions directly to the runtime and checks UI bindings, retained scene state and viewport sizing. Studio's old Foldable Preview selector has been removed. The test profile is 400 × 640 compact or 820 × 640 expanded, with a 20-point excluded gap.

## Scene and UI

The Airlock entity has a `CompanionPanel` referring to `@res://UI/Map.ui`. Its persisted `scriptBindings` map UI inputs to the `unfold.gate` script's exported fields. `ToggleButton` binds `isOn` to `gateOpen`; it queues a change through the existing UI bindings system. The game loop applies the change, moves the gate, and publishes new UI snapshots. The Drone script reads state scoped by `context.worldID`. No game behavior is built into AdaEditor.

Edit the map as a normal `.ui` document. Select Airlock in Inspector to edit the companion source and bindings. The game supports one Companion Panel per scene. Multiple panels or missing sources produce diagnostics.

## AdaScript

```swift
@res var display: DisplayLayout;

func update(context) {
    if (display.isExpanded) {
        // display.secondary contains x, y, width and height in logical points.
        posture = "EXPANDED / CONNECTED";
    } else {
        posture = "COMPACT";
    }
}
```

`DisplayLayout` is a read-only runtime snapshot. Its fields are `state`, `isExpanded`, `primary`, `secondary`, and `hinge`; absent secondary/hinge fields are null. A wide ordinary window still reports one region. AdaptiveSceneView installs host geometry before scene startup and updates it before gameplay. CameraPlugin publishes native window geometry for conventional apps.

## Swift

The compiled Swift counterpart is in AdaExamples at `Examples/EngineDemos/Demos/UI/AdaptiveSceneViewExample.swift`:

```swift
AdaptiveSceneView(layout: .foldable(expanded: expanded), make: { app in
    // Install plugins and scene entities once.
}, updateContent: { world, _ in
    guard let display = world.getResource(DisplayLayout.self) else { return }
    // Use display.primary, display.secondary and display.hinge.
})
```

Build from the engine root: `swift build --product AdaptiveSceneViewExample`.
When preparing AdaScript before installing CameraPlugin, call `DisplayLayout.registerRuntimeType()` first, on the main actor.

## Boundaries

This fixture supplies simulated layout regions and does not render two independent cameras. Region coordinates are local to the application surface. A single scene runtime owns simulation; the additional panel is AdaUI. Play changes do not modify the saved scene. Native hinge updates are exposed separately through AdaUI's `deviceHinge` environment and `WindowHingeChanged` event.

Promo drafts and capture storyboard are in `Promo/`. Public posting and an App Store release are separate steps.
