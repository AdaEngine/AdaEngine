/** Browser recipes point at actual host tools and native-generated contracts. */
export function webAuthoringDocs(contract) {
  const block = (kind, text, extra = {}) => ({
    kind,
    text,
    links: [],
    ...extra,
  });
  const heading = (text) => block("heading", text, { level: 2 });
  const code = (text, language = "json") => block("code", text, { language });
  const article = (id, title, blocks) => ({
    id,
    title,
    section: "Editor",
    source: "Browser authoring contract / " + contract.fingerprint,
    platforms: ["web"],
    blocks,
  });
  return [
    article("WebInputActions", "Browser input actions and KeyCode encoding", [
      block(
        "text",
        "Configure gameplay input with editor_project_configure. Discover keyboard, mouse, gamepad and touch names through editor_input_describe. Action names are user-authored, case-sensitive strings. Bind Input with @res(optional: true) and check available() in tests.",
      ),
      heading("Keyboard bindings: Space, arrows and named actions"),
      block(
        "text",
        "KeyCode case names are not the stored enum values. Space is named space but is encoded as a literal space; arrowRight is encoded as 124. Mouse buttons are encoded numerically. Supply kind and name to the configuration tool; it performs native serialization. Never save key._0 = space.",
      ),
      code(
        JSON.stringify(
          {
            tool: "editor_project_configure",
            arguments: {
              inputActions: [
                {
                  name: "Jump",
                  deadZone: 0.2,
                  bindings: [
                    { kind: "key", name: "space" },
                    { kind: "mouseButton", name: "left" },
                    { kind: "touch", name: "touch" },
                  ],
                },
              ],
            },
          },
          null,
          2,
        ),
      ),
      block(
        "text",
        "The corresponding native .ada/project.json inputActions section is:",
      ),
      code(JSON.stringify(contract.input.example, null, 2)),
      heading("Gamepad axes, mouse movement and touch lifecycle"),
      block(
        "text",
        "Use gamepadAxis names such as leftStickX.positive and leftStickX.negative. deadZone is a finite number in [0, 1); the default is 0.2. Gamepad button bindings match any connected controller. mouseScroll uses positive or negative; mouseMotion uses mouseMotion. touch means held while a finger is down; touchEvent names began, moved, ended and cancelled are one-frame events. Use editor_input_describe to get the exact supported names and encodings.",
      ),
      code(
        JSON.stringify(
          {
            inputActions: [
              {
                name: "MoveRight",
                deadZone: 0.2,
                bindings: [
                  { kind: "gamepadAxis", name: "leftStickX.positive" },
                ],
              },
            ],
          },
          null,
          2,
        ),
      ),
      heading("Mouse click and touch screen input bindings"),
      block(
        "text",
        "Mouse and touch are alternatives for one named action. Left mouse button is mouseButton/left; any held finger is touch/touch. Use touchEvent/began for a one-frame contact event. These named bindings go through editor_project_configure:",
      ),
      code(
        JSON.stringify(
          {
            inputActions: [
              {
                name: "Activate",
                bindings: [
                  { kind: "mouseButton", name: "left" },
                  { kind: "touch", name: "touch" },
                ],
              },
            ],
          },
          null,
          2,
        ),
      ),
      heading("Input diagnostics and repair"),
      block(
        "text",
        "Input configuration, metadata writes and metadata patches reject invalid names, values and duplicate bindings before document or Undo changes. A failure returns diagnostics with the exact inputActions array path and editor_input_describe as the repair tool. A saved edit is not proof of gameplay: run editor_build, then exercise input with editor_play_input and inspect logs/frames.",
      ),
    ]),
    article(
      "WebSceneComponents",
      "Browser scene entities and component payloads",
      [
        block(
          "text",
          "Use editor_components_describe for built-in and source-defined component schemas. Read editor_scene_get immediately before edits; pass its revision to editor_scene_apply. createEntity takes id/name/enabled/parentID/components; addComponent and setComponent take entityID/typeName/payload. Replacement payloads retain fields you want to keep. Hierarchy changes are atomic and participate in Undo. Required components below must be present on the same entity, except Visibility which renderable components insert automatically. For a new source-defined component, use editor_project_apply to write its declaration and attach it in the SAME transaction; expectedGeneration comes from editor_project_context.",
        ),
        ...contract.components.flatMap((component) => [
          heading(component.typeName),
          block(
            "text",
            component.description +
              "\nScene component payload. Required components: " +
              (component.requiredComponents.join(", ") || "none") +
              ".\nFields: " +
              component.fields
                .map(
                  (field) =>
                    field.name +
                    " (" +
                    field.kind +
                    ", " +
                    field.coding +
                    (field.minimum === undefined
                      ? ""
                      : ", minimum " + field.minimum) +
                    ")",
                )
                .join("; ") +
              "." +
              (component.typeName === "AdaScene.Mesh3DComponent"
                ? " Mesh size must be positive and at most 100000; mesh is one of Quad, Circle, Cube, Sphere or Plane."
                : ""),
          ),
          code(component.defaultPayloadJSON),
          ...component.fields
            .filter((field) => field.examples)
            .flatMap((field) => [
              block(
                "text",
                "Native serialized alternatives for " +
                  component.typeName +
                  "." +
                  field.name +
                  ":",
              ),
              code(JSON.stringify(field.examples, null, 2)),
            ]),
          ...(component.requiresAsset
            ? [
                block(
                  "text",
                  "Replace the placeholder resource path with an existing project asset. Use @res:// paths within Assets; generator tools create new files rather than overwrite them.",
                ),
              ]
            : []),
          ...(component.ignoredNativeFields.length
            ? [
                block(
                  "text",
                  "Native-only fields ignored by this Player: " +
                    component.ignoredNativeFields.join(", ") +
                    ".",
                ),
              ]
            : []),
        ]),
        heading(
          "Script-defined components: declaration, stable ID and scene attachment",
        ),
        block(
          "text",
          "A source-defined @component is attached directly under its stable id in entity.components. It does not use a ScriptableComponents container. @scriptable objects and @component data are different mechanisms. Ask editor_components_describe after writing sources to discover the native parser's fields and defaults; projectValidation tells you whether schemas were parsed or a full compile was run.",
        ),
        code(
          '@component(id: "game.player")\nstruct PlayerState {\n    @export var speed = 120.0;\n}\n\n@system(id: "game.movement")\nclass MovementSystem {\n    @res(optional: true) var input: Input;\n    @query(PlayerState, Transform) var players;\n    func update(context) {\n        if (!input.available()) return;\n        for (var row in players) {\n            var position = row.transform.position;\n            position[0] += input.getActionStrength("MoveRight") * row.playerState.speed * context.deltaTime;\n            row.transform.position = position;\n        }\n    }\n}',
          "ada",
        ),
        code(
          JSON.stringify(
            {
              id: "player",
              name: "Player",
              enabled: true,
              parent: null,
              components: {
                "AdaTransform.Transform": {
                  position: [0, 0, 0],
                  rotation: [0, 0, 0, 1],
                  scale: [1, 1, 1],
                },
                "game.player": { speed: 120 },
              },
            },
            null,
            2,
          ),
        ),
        block(
          "text",
          "Add a Sprite or Mesh3DComponent for a visible object. Query PlayerState together with Transform so movement affects the player rather than every transform, including cameras. Define the MoveRight action separately. Build and inspect visible Play after connecting the sources and scene.",
        ),
        heading(
          "UIComponent and ScriptableComponents: browser capability boundaries",
        ),
        block(
          "text",
          "This is Web Player API " +
            contract.runtimeAPI +
            ". @view is unavailable. Native UIComponent/ScriptableComponents HUD recipes are not supported by this Player; A2UI forms are assistant chat UI, not game HUD. Native process, terminal, LSP and TestWorld host tools are unavailable. Use the supplied tool schemas and browser-compatible examples; compiler API presence alone does not establish scene-component support.",
        ),
      ],
    ),
    article(
      "WebExamples",
      "Complete browser game examples: flappy runner and keyboard movement",
      [
        block(
          "text",
          "editor_examples_list searches complete browser-compatible projects by id, description and technique tags. flappy finds side-scroller-3d with pooled obstacles, Space/click/touch flap, R restart, collisions, score and all three WAV sounds. Read it with editor_examples_read; import text and binary assets atomically using editor_examples_apply with expectedGeneration from editor_project_context. Imported sources replace gameplay Sources/Tests in one Undo step, preserving project identity, chat, notes and existing assets. Build and verify actual Play; source and asset completeness alone is not gameplay proof.",
        ),
        block(
          "text",
          "keyboard-movement contains a visible 2D Sprite, fixed camera, PlayerState stable component ID, movement source and MoveLeft/MoveRight actions. Only PlayerState + Transform entities move. basic-3d-scene supplies camera, PBR mesh and light. runtime-component demonstrates data components and startup/update systems; it has a static reference sprite and reports counter values in Play logs. The browser runner intentionally omits native UIComponent and ScriptableComponents HUD bindings; inspect phase/score through Play logs instead.",
        ),
      ],
    ),
  ];
}
