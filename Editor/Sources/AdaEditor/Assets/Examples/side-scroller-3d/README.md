# Side Runner 3D

A compact AdaScript game: a body flaps through gaps in scrolling columns, seen from the side in 3D.
Use it as the reference for how a game is laid out, not as a template to copy blindly.

## Layout (one responsibility per file)

| Path | Responsibility |
| --- | --- |
| `Sources/Config.ada` | Every balance number and phase constant. |
| `Sources/Rules.ada` | Pure rules (gap heights, collision, passing, cue routing). Unit-testable. |
| `Sources/Components/*.ada` | Data only: `Player`, `Obstacle`, `SoundCue`, and the `GameState`, `PlayerIntent`, `Cues` components that live on one `Game` entity (authored in the scene and readable by `TestWorld`, which cannot read `@resource`). |
| `Sources/Systems/*.ada` | One `@system` per behaviour, ordered with `@before`/`@after`: input, phase, restart, flight, obstacles, collision, score, audio. |
| `Sources/UI/*.ada` | HUD wording, the small `HudModel` presentation model and the `@scriptable` that feeds `Assets/UI/Hud.ui` (a scriptable can bind script components; the model keeps gameplay systems free of HUD wording). |
| `Assets/UI/Hud.ui` | HUD layout with `score`, `status` and `hint` inputs. |
| `Tests/*.ada` | `@test` functions; `TestWorld` has no `Input`, so tests press keys by replacing `PlayerIntent` on the `Game` entity. |
| `Generators/*.txt` | Source for `editor.audio.generate` / `editor.model.generate`. Run them to create `Assets/Audio/*.wav` and `Assets/Models/runner.glb`. |
| `Assets/Scenes/Main.ascn` | Camera, light, ground, the player, four reusable obstacle columns, one AudioSource per cue, the `Game` entity with the round data and the HUD. |

## Flow of one frame

`InputSystem` writes the `PlayerIntent` component -> `PhaseSystem` changes the phase and requests resets -> `RestartSystem`
resets entities -> `FlightSystem` applies flap and gravity -> `ObstacleSystem` scrolls and reuses columns ->
`CollisionSystem` ends the round -> `ScoreSystem` counts passed columns -> `AudioSystem` plays raised cues and clears them -> `HudSystem` writes the HUD text.

## Before the first Play

1. Generate the three sounds from `Generators/*.sound.txt` into `Assets/Audio/flap.wav`, `score.wav`, `crash.wav`.
2. Optionally generate `Generators/bird.model.txt` into `Assets/Models/runner.glb` and replace the player's placeholder sphere with a `Model3DSource`.
3. Build and run visible Play. Controls: Space or click flaps and retries, R restarts.
