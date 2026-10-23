# Browser agent autonomy

The browser agent must be able to discover the supported authoring contracts,
create a playable scene and gameplay sources, diagnose invalid edits, repair them,
and verify the result without a developer supplying missing JSON or engine APIs.

## Acceptance requirements

1. Documentation search ranks relevant sections, preserves exact API identifiers,
   understands common English and Russian authoring queries, and returns excerpts
   from the matching section with a stable reference for reading it.
2. Authoring references identify the browser runtime version, supported features,
   and unavailable native features. A native workflow must not silently advertise
   an unsupported browser operation as a working recipe.
3. Component discovery covers every built-in component accepted by Web Player and
   the current project's compiled script components. It describes stable type IDs,
   fields, defaults, references, required components, and authoring limitations.
4. Input discovery covers keyboard, mouse, gamepad and touch. The agent can author
   named physical inputs without guessing Swift associated-value encoding. The
   saved representation remains compatible with the production InputAction codec.
5. Scene/configuration tools advertise complete operation schemas. Invalid input
   and component payloads produce a structured diagnostic before committing the
   edit. Rejection preserves the document, Undo history and last working preview.
   Coordinated source/scene edits must allow a newly declared script component.
6. Examples are complete projects: sources, scene, input/runtime configuration,
   references and required assets. Search metadata includes advertised genre and
   technique terms. The supplied examples must load in this Web Player profile.
7. API lookup returns structured types, members and signatures even when the
   current scene cannot load. Searching for a member must find its owning type.
8. The agent receives validation/runtime diagnostics with the project revision;
   saving an edit is not reported as proof that the runtime accepted it. Failure
   feedback includes the affected path/entity/component and a useful repair hint.
9. Deterministic tests cover search relevance, complete example export, native
   serialization parity, invalid edits, dynamic components and repair. A live
   local Codex run must discover the references, author a small game and verify
   observable Play behavior without developer corrections.

## Completion evidence

Record the exact commands and browser runs for each requirement in the
decomposition map. Unit tests alone do not prove browser/WASM parity or agent
autonomy. A successful native example build alone does not prove compatibility
with the browser's supported component set. Do not mark this objective complete
until the live authoring and repair scenario succeeds.

## Live evaluation

Use an authenticated local development Cloud and select Local Codex in Settings.
Create a separate QA project from the ordinary composer; preserve existing user
projects. Give a game brief without JSON, component IDs or copied implementation:

> Create a small 2D game: move a purple square with the arrow keys, collect five
> golden stars and avoid red obstacles. Collecting every star wins; R restarts.
> Find the documentation, build the game and verify the controls in Play yourself.

Observe the actual agent tool results and Player, including:

- Relevant documentation/input/component/API discovery, complete source and scene
  authoring, and committed revisions that really render in the fixed Player.
- Actual keyboard input followed by changed frames and gameplay log events;
  a successful input dispatch alone is not movement/collection proof.
- Loss, victory and restart from real input, with the current revision identified.
- A failed compile/runtime/authoring operation followed by the agent's own repair
  and a successful repeat. Do not supply the missing API or edit its game code.
- Honest incomplete results if the host fails. Fix host defects separately, record
  the interruption and repeat acceptance; do not count a retained older frame as
  evidence for an unsuccessful new revision.

Save screenshots, visible tool results and an exported QA project. Record the
model, normal brief/continuations, discovered host defects and precise limits in
the decomposition map. Keep unit, native CLI, real WASM and live agent evidence
separate. No production deployment or funded hosted inference is needed.

## Retrieval evaluation cases

Use these as acceptance cases rather than testing only whether search returns
anything. Both the ranking and returned excerpt must answer the question. Exact
symbols should reach their schema/API before broad workflow prose. A capability
gap should be reported explicitly instead of returning an unrelated native guide.

| Query | Required useful result |
|---|---|
| `KeyCode space JSON` | Input contract with canonical Space encoding and named-input authoring example |
| `как привязать пробел для прыжка` | The same input contract and a complete Jump action example |
| `keyboard bindings` | Keyboard binding schema and exact persisted example, not A2UI input controls |
| `gamepad axis dead zone` | Axis, direction and dead-zone constraints with a valid example |
| `нажатие мыши и касание экрана` | Mouse and touch binding alternatives for one named action |
| `create entity with custom component` | Scene operation schema plus declaration/stable-ID/payload example |
| `добавить компонент к сущности` | Component attachment operation with required fields and dependencies |
| `Mesh3DComponent size` | Supported browser mesh payload and size/primitive constraints |
| `isActionJustPressed` | Structured member signature and description owned by Input |
| `UIComponent` | Accurate browser capability result; do not imply native HUD support exists |
| `flappy` | Complete browser-compatible runner example including scene and configuration |
| `неизвестный_тип_без_совпадений` | An honest empty result and discovery guidance, not an arbitrary article |

Keep search results bounded and section IDs stable; verify reading a returned
section reproduces its context. Include punctuation, quoted identifiers,
multiword questions and empty queries in deterministic coverage. Preserve user
project text and source code verbatim.

## Non-goals

This work does not add terminal access, external MCP, arbitrary native components,
Swift project builds, publication, or unsupported renderer features to the
browser. Completeness means an accurate, discoverable contract for the browser's
implemented authoring capabilities, including explicit capability gaps.
