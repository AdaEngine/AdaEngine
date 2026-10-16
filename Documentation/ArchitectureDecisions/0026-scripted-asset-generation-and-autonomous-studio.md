# ADR-0026: Scripted asset generation and an autonomous workflow for Studio agents

- Status: Accepted
- Date: 2026-10-16
- Implementation: Implemented (not released). Provider-based audio generation is recorded under
  [Future work](#future-work) and is not part of this decision's requirements.

## Context

The goal is a Studio agent that takes a game idea from a short brief to a finished, checked and playable
result: it asks what it needs, writes a design document, splits the work into plans, produces the art, sound
and models, writes the code and keeps running, playing and checking until the result matches the design.

An inventory of Studio's agent tools showed which parts existed:

- **Code and project**: project context, documentation, API and example search, Gravity diagnostics, build,
  runtime simulation (mobile), visible Play with frame capture. The `ada-game-builder` workflow drives a playable
  slice and its verification.
- **Scenes and assets**: structured scene editing with undo, atlases, tile sets, tile maps, texture rendering,
  model import and material edits, and image generation through a configured provider.

And which did not:

1. **No audio at all.** The engine plays sound (`AudioResource`, `AudioPlaybackController`), but an agent could
   neither create a sound nor check one. A sound could not be played from a scene file, from the inspector or from
   AdaScript: `AudioComponent` holds a live controller and has no serialized form, and `AudioResource` registered
   only the extension `audiores`, so `AssetsManager` could not load a `.wav`.
2. **No 3D or 2D content creation without a provider.** Models could be imported and edited but not made (see
   [ADR-0025](0025-voxel-graphics-and-magicavoxel-import.md) for voxels); pixel art needed `editor.image.generate`,
   which needs credentials.
3. **No workflow for the whole job.** `ada-game-builder` deliberately avoids planning documents as a precondition
   for small work. Nothing described how to clarify a brief, write acceptance criteria, plan milestones or run a
   repeated accept-and-fix loop for a whole game.

Agents also cannot listen to a sound or judge a picture by pixel counts, so every generator needs a way to be
checked with measurements or with the existing frame and image tools.

## Decision

### 1. Scripted generation is the provider-free asset path

Each asset kind has a generator that takes AdaScript source and returns the encoded file:

| Tool | Script entry | Output | Host encoder |
| --- | --- | --- | --- |
| `editor.voxel.generate` | `func build(model)` | `.vox` | `VOXWriter` |
| `editor.model.generate` | `func build(model)` | `.glb` | `GLBWriter` over `ProceduralGeometry` |
| `editor.audio.generate` | `func build(sound)` | `.wav` (mono, 16-bit PCM) | `SoundSynth` and `WAVWriter` |
| `editor.sprite.generate` | `func build(sprite)` | `.png` (RGBA) | `PixelCanvas` and `PNGWriter` |

All four share one contract:

- **Isolation.** `AdaScriptGeneratorRunner` runs the source in a fresh Gravity VM with the community policy:
  the source is validated and instrumented, limited to 64 KiB, and runs under a checkpoint and wall-clock budget
  (2,000,000 checkpoints, 3 seconds). The script sees only a builder object; it has no file, network, scene,
  engine or `System` access. The builder is a thin AdaScript class over a host bridge that validates every
  argument and records the first failure, which becomes the error returned to the agent.
- **Host-side output.** The script describes content; the host builds geometry or samples, bounds the result
  (part, vertex, voice, duration and canvas limits) and encodes the file. Writers are pure Swift with no
  platform image or audio framework, so output is identical on every platform.
- **Safe writes.** The destination is a project-relative path under the assets root with the tool's fixed
  extension. Existing files are never overwritten, so each revision gets a new name and a failing script writes
  nothing.
- **Result.** The tool returns the `@res://` reference, a summary the agent can check (sizes and counts, parts and
  materials, or audio measurements) and `requiresRebuild`.

Gravity bridge methods take at most four arguments, so wider calls (for example a five-argument rectangle) are
staged by the builder class through a setter call. This is invisible to scripts.

Scripts were chosen over provider calls for this slice because they work offline and without credentials, are
deterministic and regenerable (a revised script gives a revised asset), cost nothing, and can be validated by
measurement. The price is style range: shapes, pixel art, synthesized effects and chiptune-like loops, not
painted art, recorded sound or organic meshes.

#### Procedural models

`ProceduralGeometry` builds boxes, planes, revolved shapes (sphere, cylinder, cone, capsule, torus and an
arbitrary `lathe` profile) and flat-shaded triangle meshes. Triangles wind so that `cross(b - a, c - a)` points
outward, like the engine's own primitives. Revolved profiles keep smooth normals along gentle turns and split
them at corners sharper than 60 degrees. `GLBWriter` writes a hierarchy of nodes with PBR materials; parts are
created in order and a parent must exist before its child. Coordinates are engine axes, so the existing glTF
import and `Model3DSource` path place the model without conversion.

#### Pixel art

`PixelCanvas` is a palette-indexed canvas (index 0 transparent, up to 512 by 512) with pixels, rectangles, lines,
ellipses, an outline pass and left-to-right mirroring. `PNGWriter` emits uncompressed (stored) deflate blocks
with CRC and Adler checksums. Sprites are small, so the larger file is acceptable, and the encoder needs no zlib.

#### Sound

`SoundSynth` mixes voices (sine, square, saw, triangle, noise) with ADSR, exponential pitch sweep, vibrato,
pulse width, one-pole low-pass and high-pass filters, a global echo, deterministic seeded noise and final peak
normalization. Limits: 30 seconds, 256 voices, 120 voice-seconds of synthesis, 8-48 kHz.

### 2. Sounds are verified by measurement

`AudioAnalyzer` computes duration, peak and RMS in dBFS, clipped samples, DC offset, leading and trailing
silence, dominant frequency and spectral centroid of the loudest window (radix-2 FFT) and a ten-slice loudness
envelope. `editor.audio.generate` returns them, and `editor.audio.inspect` returns them for any WAV (8-32-bit PCM
or float) under the assets root. The workflow defines what to expect from effects, loops and ambience. These
numbers show that a sound has the intended pitch, shape and level; they do not show that it sounds good, and
workflows must say "measured", not "heard".

### 3. Sounds play from scenes, the inspector and scripts

- `AudioResource` decodes from the bytes the asset system read, so virtual `@res://` paths and bundles work, and
  accepts `wav`, `mp3` and `flac` besides `audiores`. `AudioPlugin` registers it as an asset type.
- `AudioSource` is a serializable component (`source`, `volume`, `loops`, `autoplay`, `play`, `stop`).
  `AudioSourceSystem` loads the resource, plays it from the entity's `Transform` position, applies volume and
  looping each update, and reports a load failure on `AudioSourceState` instead of crashing. A script triggers a
  sound by setting `play` (the sound restarts and the flag is cleared) and ends it with `stop`. The component is
  registered even when no audio device exists, so scenes that use sounds still load.
- The Studio inspector exposes the component (`Audio Source`) through the ordinary descriptor registry.

Sounds are spatial: distance to the audio listener (placed on active cameras) lowers volume. Music and interface
sounds are put on the camera entity. A non-spatial mode, buses and a mixer are not part of this decision.

### 4. Skills teach the tools, and their examples run

Bundled skills, discovered like the existing ones, describe each generator's API, recipes and checks:
`ada-voxel-models`, `ada-procedural-models`, `ada-pixel-art` and `ada-sound-design`. A test extracts every
runnable example from these skills and generates it, so documented code cannot rot, and checks the sound
recipes against the skill's own guidance (no clipping, no leading silence).

### 5. An autonomous workflow for whole games

`ada-autonomous-studio` wraps `ada-game-builder`. It does not replace the quick path: small features and bugs
keep using `ada-game-builder` alone. For a whole game it prescribes:

1. **Recover** from `DESIGN.md`, `PLAN.md` and `PROGRESS.md` (project notes location or `Design/`) and resume.
2. **Clarify** in one message with at most five questions, each with a default; otherwise record assumptions.
3. **Design document** with core loop, controls, rules, content, art direction (fixed palette), audio table, UI,
   technical choices, non-goals and numbered **acceptance criteria**, each naming its verification method.
4. **Plan** as milestones that each end in something that runs: M1 playable core with placeholders, M2 content,
   M3 art and sound, M4 interface and polish; tasks are checkboxes small enough for one verified step.
5. **Execute** task by task: implement, validate, build, exercise (simulation or visible Play with a frame),
   record evidence. After three failed repairs of one problem, change approach, then record a blocker and move on.
   Criteria are never weakened to pass.
6. **Produce assets** with a mapping from need to tool, in the design's style, reusing before generating.
7. **Accept** by walking every criterion with the stated verification, at most three full passes, keeping the
   evidence classes apart: build, validation, simulation, play frame, measurement and manual. Anything that
   needs a person (how it feels, how it sounds) is reported as not verified.
8. **Report** the delivered game, controls, acceptance table, gaps and next steps. Publishing stays a separate,
   explicitly authorized step.

## Consequences

- An agent can make a complete 2D or low-poly 3D game, including art, tiles, sounds and models, on a machine with
  no network access and no provider account, and can tell whether each asset matches its intent.
- The tools store the generated asset, not the script that made it. Agents are told to keep a note of each
  generated asset in `PROGRESS.md`; storing the generator source next to the asset is a possible later improvement.
- The workflow's quality depends on the model following it. The ADR does not claim end-to-end results for any
  given game; it provides the tools, the checks and the procedure, and the tests above validate the tools.
- The `AudioResource` extension list and `AudioPlugin` registration change affects every project that loads
  audio files through the asset system; this makes loading by path work where it previously could not.
- `AudioComponent`, which holds a live controller, remains for Swift code. `AudioSource` is the data-driven form.

## Future work

Recorded so the next step is not lost; none of it is required by this ADR.

1. **Provider-based audio generation.** Music, voices and realistic effects need a model provider. Follow the
   pattern of `editor.image.generate`: an `ai.audioGeneration` setting with the credential store, optional Cloud AI
   wallet quote, reservation and settlement, a separate tool (working name `editor.audio.provider.generate`) so
   script synthesis stays offline, output written as a WAV under the assets root, and the same
   `editor.audio.inspect` checks and `AudioSource` playback. `ada-sound-design` and the audio table in the design
   document would then choose between script synthesis and a provider. Until a provider exists, workflows state
   that finished music and voices are unavailable instead of faking them.
2. **Gameplay verification on desktop.** Stepped simulation with held input and entity inspection
   (`editor.runtime.*`) exists on mobile only. A desktop equivalent lets the acceptance pass check rules, not just
   frames.
3. **Organic and animated characters.** Skinned mesh generation and skeletal clip authoring.
4. **Audio features.** Stereo and panning, buses and a mixer, loop points, a non-spatial mode and streaming for
   long music.
5. **Sprite animation.** Frame-sheet generation with slicing metadata and previewing.

## Delivery

- [x] Shared isolated generator runner; voxel generator moved onto it.
- [x] Procedural geometry and `GLBWriter`; `editor.model.generate`.
- [x] `PixelCanvas`, `PNGWriter`; `editor.sprite.generate`.
- [x] `SoundSynth`, `WAVWriter`, `WAVReader`, `AudioAnalyzer`; `editor.audio.generate` and `editor.audio.inspect`.
- [x] `AudioResource` loads WAV, MP3 and FLAC through the asset system.
- [x] `AudioSource` component and system, plugin registration, Studio inspector descriptor.
- [x] Skills: `ada-procedural-models`, `ada-pixel-art`, `ada-sound-design`, `ada-autonomous-studio`; links from
  `ada-game-builder`, `ada-3d-assets` and the workflow documentation.
- [x] Tests: encoders and writers (`ProceduralModelTests`, `ProceduralMediaTests`), script generators
  (`AdaScriptModelGeneratorTests`, `AdaScriptMediaGeneratorTests`), engine playback of a generated WAV
  (`GeneratedAudioTests`), the component system (`AudioSourceTests`), and Studio tools, the descriptor and the
  executable skill examples (`EditorAgentModelGenerateTests`, `EditorAgentMediaGenerateTests`).
