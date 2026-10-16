---
name: ada-autonomous-studio
description: Build a complete, verified game from a brief in Ada Studio. Clarify the idea, write a design document with acceptance criteria, split it into plans, produce the art, sound and models, implement, and loop through build, play and checks until every criterion is met. Use when the user asks for a whole game, an autonomous run, or "make me a game that...".
allowed-tools: editor.project.context, editor.skills.list, editor.skills.read, editor.docs.search, editor.docs.read, editor.examples.list, editor.examples.read, editor.scene.get, editor.scene.apply, editor.build.start, editor.task.status, editor.output.read, editor.play.start, editor.runtime.start, editor.runtime.step, editor.runtime.inspect
---

# Ada Autonomous Studio

This workflow turns "I want a game like this" into a finished, checked, playable result with as little back-and-forth as the brief allows. It wraps `ada-game-builder` (load it with `editor.skills.read` for the playable-loop and verification rules) and the asset workflows. For a single feature, bug or tweak to an existing game, use `ada-game-builder` alone; do not start a design process for small work.

Three files carry the state between steps and sessions. Keep them in the project's existing notes location, or `Design/` when there is none, and always read them before doing anything else in a returning session:

- `DESIGN.md`: what the game is and how we know it is done.
- `PLAN.md`: milestones and tasks, as a checklist.
- `PROGRESS.md`: what was done, what evidence exists, open problems and decisions.

## 1. Recover

Call `editor.project.context`. Read the three files if they exist and resume from the first unchecked task; do not restart a design that exists. Look for existing scenes, scripts and assets and reuse them. If the project already holds a different game than the request, ask before changing direction.

## 2. Clarify (one round)

Ask once, in one message, only what would change the game materially, at most five questions, each with a suggested default so a short "ok" works: perspective and dimension (2D or 3D), the core challenge and how a round ends, controls and target platform, art style, and how long or large the first version should be. If the brief already answers a question, do not ask it. If the user says to decide or does not answer, record your choices as assumptions in `DESIGN.md` and continue. Do not ask again later unless a blocker needs a decision only the user can make.

## 3. Design document

Write `DESIGN.md` with these sections, short and concrete:

1. **Pitch**: one sentence, and the player's fantasy.
2. **Core loop**: the repeated action, challenge and reward; how a round starts, ends (win, lose) and restarts.
3. **Controls and camera.**
4. **Rules and numbers**: speeds, health, scores, timers, difficulty steps.
5. **Content**: levels, enemies, items, with counts for the first version.
6. **Art direction**: dimension, style, grid or unit scale, a fixed palette (list the colors), sprite sizes. Every generated asset follows this.
7. **Audio direction**: a table of sounds (name, trigger, character such as "short rising blip") and whether there is music.
8. **UI**: HUD fields, menus, game-over and restart.
9. **Technical choices**: project language and runtime, scene layout, scripts and their responsibilities, plugins and input actions.
10. **Scope and non-goals**: what is deliberately left out.
11. **Acceptance criteria**: a numbered list of observable statements ("pressing space makes the player jump and the jump sound plays", "touching an enemy shows Game Over and R restarts with score 0"). Each ends with how it is verified, using the weakest sufficient method: *build* (compiles, no diagnostics), *validate* (scene, asset or model validation), *simulation* (logic stepped with inputs), *play frame* (screenshot of visible Play at a stated moment), *measurement* (asset metrics from `editor.audio.inspect`, `editor.model.inspect`), or *manual* (needs a human: how it feels, how it sounds). A criterion that can only be checked by hand is marked *manual* from the start.

## 4. Plan

Write `PLAN.md` as milestones, each a vertical slice that ends in something that runs:

- **M1, playable core**: input, movement, the main challenge, an outcome and restart, with placeholder shapes and no polish. It must run end to end before anything else is built.
- **M2, content**: levels, enemies, items, difficulty.
- **M3, art and sound**: replace placeholders with generated sprites, models, tiles and sounds that follow the art and audio direction.
- **M4, interface and polish**: HUD, menus, feedback, game feel, camera, final balancing.

Each milestone lists its goal, tasks as `- [ ]` checkboxes small enough for one verified step, the assets it needs, and an exit check naming the acceptance criteria it completes. Order tasks so each one can be built and checked on its own.

## 5. Execute

Work one task at a time and keep the loop tight:

1. Implement the smallest change that does the task. Reuse existing assets, scenes and scripts. Follow `ada-coding`, `ada-scene-authoring` and the other workflows for the kind of work; read docs and examples with `editor.docs.search` and `editor.examples.read` instead of guessing engine APIs.
2. Check it: diagnostics, scene and asset validation, then build (`ada-build-run`). Read errors fully before fixing and revalidate after every fix.
3. Exercise it: step the simulation where the host offers it, and run visible Play with a frame capture for anything visual (`ada-visual-verification`).
4. Record it: tick the task in `PLAN.md` and add a line to `PROGRESS.md` with what changed, the files, and the evidence (which check, what it showed).

When a check fails, change the cause rather than the check. After three failed repairs of the same problem, stop repeating: re-read the relevant docs, try a different approach, and if it still fails record it in `PROGRESS.md` as a blocker and move to work that does not depend on it. Ask the user only for a decision that you cannot make from the design. Never delete or rewrite acceptance criteria to make them pass; if one is wrong, change it explicitly in `DESIGN.md`, note why in `PROGRESS.md`, and continue.

## 6. Produce assets with the right tool

Generate only what the design lists, in the style and palette of `DESIGN.md`, reusing before creating. Keep each file purposeful: do not keep near-duplicates.

| Need | Use |
| --- | --- |
| Sprites, icons, characters, items, UI pieces | `ada-pixel-art` (`editor.sprite.generate`), then `editor.atlas.pack` or `editor.tileset.create` |
| Tile sheets, tile sets and levels | `ada-pixel-art` for the sheet, `ada-assets` for `editor.tileset.*` and `editor.tilemap.*` |
| Sound effects and short loops | `ada-sound-design` (`editor.audio.generate`), checked with `editor.audio.inspect`, played with the `AudioSource` component |
| 3D props, scenery, blocky objects | `ada-procedural-models` (`editor.model.generate`) or `ada-voxel-models` (`editor.voxel.generate`) |
| Textures and materials | `editor.texture.render` for patterns and flat PBR maps; `editor.image.generate` when a provider is configured; `ada-3d-materials` |
| Existing models | `ada-3d-assets` (`editor.model.import`); `editor.store.*` for the asset store |
| Scenes, entities, components | `ada-scene-authoring` |
| HUD, menus, forms | `ada-ui-forms` |

Not available yet: finished music and voices (they need an audio generation provider), organic or rigged character models and skeletal animation. Use short generated loops or silence, and block-style or sprite characters, and say so in the report instead of faking it.

## 7. Accept

When the milestones are done, walk the acceptance criteria one by one. For each, run the verification named in the design and write the result and its evidence in `PROGRESS.md`:

- ✔ with the evidence type (build, validate, simulation, play frame, measurement).
- ✘ with what is wrong; add fix tasks to `PLAN.md`, return to step 5 and repeat the pass. Do at most three full acceptance passes unless the user asks for more.
- *manual*: list it as not verified with the exact thing a person should try.

Keep these evidence classes apart: compiling is not gameplay, simulation is not rendering, a frame is not sound, and measured audio is not heard audio. Do not mark a criterion verified by a method that cannot show it.

## 8. Report

Finish with: what the game is and how to run it, the controls, what was built per milestone, the acceptance table (criterion, result, evidence), what is not verified or missing (including features waiting on a provider), and sensible next steps. Publishing, purchases and account actions need explicit authorization and are not part of finishing the game.
