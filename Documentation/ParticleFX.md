# Particle FX

Particle FX is a CPU-simulated 2D effect in `AdaSprite`, rendered through the existing sprite batching and instancing paths. An effect contains up to 16 emitters, each with up to 4,096 live particles. Particles do not create separate ECS entities.

In Studio choose **New File → Resources → Particle FX**. Open the `.particles` resource to edit emitters, preview playback, change lifetime curves, or add the effect to an open scene. Edits save immediately and enter the resource editor's Undo/Redo history. Reload explicitly if another program changes the file; the editor refuses to overwrite those changes.

The editor's live particle count refreshes at most four times per second. Simulation and rendering still run every frame; telemetry updates do not rebuild the settings form or retessellate its unchanged fields.

## Resource

`.particles` uses YAML on native platforms. Unspecified emitter fields use the engine defaults.

```yaml
version: 1
seed: 1
emitters:
  - name: Sparks
    shape: circle
    radius: 12
    space: world
    emissionRate: 0
    burstCount: 100
    duration: 0.2
    loops: false
    lifetimeMin: 0.5
    lifetimeMax: 1.5
    direction: 90
    spread: 180
    speedMin: 30
    speedMax: 100
    gravity: [0, -80]
    sizeMin: 2
    sizeMax: 6
```

Shapes are `point`, `box` and `circle`. Box dimensions, circle radius and emitter offset use scene units. Angles and angular velocity use degrees. Local particles follow the emitter; world particles retain their spawn transform. Gravity uses the corresponding coordinate space.

`texture` is optional: an empty path renders white quads tinted by the effect. Nonempty paths load a Texture2D through AdaAssets. Relative paths resolve next to the effect file. Textures are shared, while simulation buffers belong to each instance.

`startColor` and `endColor` interpolate over the particle lifetime. `sizeCurve` and `opacityCurve` contain ordered `keys` with `time` in 0…1 and nonnegative `value`; the editor lets you add and drag these keys.

```yaml
sizeCurve:
  keys:
    - {time: 0, value: 0.25}
    - {time: 0.2, value: 1}
    - {time: 1, value: 0}
```

## Swift

`SpritePlugin`, included by `DefaultPlugins`, registers the effect asset, emitter component, simulation and render extraction. Install `TransformPlugin` before `SpritePlugin` when composing plugins manually.

```swift
let effect = try await AssetsManager.load(ParticleEffect.self, at: "@res://Effects/Sparks.particles", handleChanges: true)
world.spawn("Sparks") {
    Transform(position: [100, 50, 0])
    ParticleEmitter(effect: effect)
}
```

Set `isEmitting = false` to stop spawning and let existing particles expire. Set `isPaused = true` to freeze the effect. Increment `restartCount` to discard existing particles and replay with the authored seed. `particleCount` exposes the current live count.

## AdaScript

The same component constructor and reflected controls work through the normal AdaScript bridge:

```text
@system class SpawnSparks {
    func update(context) {
        var effect: ParticleEffect = Assets.preload("@res://Effects/Sparks.particles");
        context.world.spawn([Transform(position: [100, 50, 0]), ParticleEmitter(effect: effect)]);
    }
}
```

Call the spawn operation in response to a gameplay event; the example's update method would create a new emitter every frame.

```text
@system class StopSparks {
    @query(ParticleEmitter) var effects;
    func update(context) {
        for (var entity in effects) {
            entity.particleEmitter.isEmitting = false;
        }
    }
}
```

## Initial scope

This version supports alpha-blended 2D particles, multiple emitters, bursts, continuous emission, local/world space, seeded randomness, gravity, color interpolation and lifetime curves. Simulation advances at 120 Hz and accepts at most 0.25 seconds per frame to bound hitch recovery work.

3D billboarding, additive/multiply materials, collision modifiers, flipbook particles and GPU simulation are future extensions. Native AOT scene binding and browser export of particle resources have not been validated in this version.
