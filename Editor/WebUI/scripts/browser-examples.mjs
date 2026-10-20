import { parse } from "yaml";

/** Adapt native fixtures to the actual browser capability set, never source-only folders. */
export function browserExamples(contract) {
  const builtins = new Map(contract.components.map((c) => [c.typeName, c]));
  const examples = structuredClone(contract.examples);
  const transform = (position = [0, 0, 0]) => ({
    position,
    rotation: [0, 0, 0, 1],
    scale: [1, 1, 1],
  });
  for (const example of examples) {
    const files = example.files;
    const metadata = JSON.parse(files[".ada/project.json"]);
    metadata.paths = {
      sources: "Sources",
      assets: "Assets",
      resourceRoots: ["Assets"],
    };
    delete metadata.ai;
    delete metadata.run;
    const scenePath = metadata.runtime.entry.scene;
    const value = parse(files[scenePath]);
    for (const entity of value.entities) {
      entity.parent ??= null;
      for (const [name, payload] of Object.entries(entity.components)) {
        const descriptor = builtins.get(name);
        if (!descriptor) continue;
        const roots = new Set(descriptor.fields.map((field) => field.path[0]));
        for (const key of Object.keys(payload))
          if (!roots.has(key)) delete payload[key];
      }
    }
    if (example.id === "side-scroller-3d") {
      for (const entity of value.entities) {
        delete entity.components["AdaUI.UIComponent"];
        delete entity.components["AdaScene.ScriptableComponents"];
      }
      for (const name of Object.keys(files)) {
        if (
          name.startsWith("Sources/UI/") ||
          name === "Sources/Systems/HudSystem.ada" ||
          name.startsWith("Assets/UI/")
        )
          delete files[name];
        if (name.startsWith("Generators/")) {
          files["Docs/" + name.slice(11)] = files[name];
          delete files[name];
        }
      }
      example.description =
        "Complete browser 3D flappy / side-scroller runner: pooled obstacles, Space/click/touch flap, R restart, gravity, collision, score state and three generated WAV sound cues. Native game HUD is unavailable in this Player; round state can be inspected in logs. Includes source, scene, input configuration and all required audio assets.";
      files["Sources/Systems/StatusSystem.ada"] =
        `import { GameState } from "../Components/GameState.ada";
@after(id: "runner.score")
@system(id: "runner.browser-status")
class BrowserStatusSystem {
    @query(GameState) var games;
    var previous = "";
    func update(context) {
        for (var game in games) {
            var status = "phase=" + game.gameState.phase + " score=" + game.gameState.score;
            if (status != previous) { print(status); previous = status; }
        }
    }
}`;
      files["README.md"] =
        "# Browser side runner\n\nSpace, left click or touch starts/flaps. R restarts. Avoid the floor, ceiling and pipes. All three WAV cues are included; no generation step is required. The bird and pipes use built-in meshes.\n\nThis browser adaptation removes native UIComponent and scriptable HUD bindings. Play logs expose phase and score; there is no native HUD. Use editor_examples_apply to import the complete project with binary sounds. The original generator recipes are in Docs/.\n";
    }
    if (example.id === "keyboard-movement") {
      const player = value.entities[0];
      player.components["example.player"] = { speed: 120 };
      player.components["AdaSprite.Sprite"] = {
        ...structuredClone(builtins.get("AdaSprite.Sprite").defaultPayload),
        size: { width: 80, height: 80 },
      };
      value.entities.push({
        id: "camera",
        name: "Camera",
        enabled: true,
        parent: null,
        components: {
          "AdaTransform.Transform": transform(),
          "AdaRender.Camera": structuredClone(
            builtins.get("AdaRender.Camera").defaultPayload,
          ),
        },
      });
      metadata.runtime.plugins.preset = "game2d";
      files["Sources/Game.ada"] = `@component(id: "example.player")
struct PlayerState { @export var speed = 120.0; }
@system(id: "example.movement")
class Movement {
    @res(optional: true) var input: Input;
    @query(PlayerState, Transform) var players;
    func update(context) {
        if (!input.available()) return;
        var dx = input.getActionStrength("MoveRight") - input.getActionStrength("MoveLeft");
        for (var row in players) {
            var position = row.transform.position;
            position[0] += dx * row.playerState.speed * context.deltaTime;
            row.transform.position = position;
        }
    }
}`;
      example.description =
        "Complete browser 2D keyboard movement and custom component attachment: A/D or left/right arrows move the visible Player sprite. Queries PlayerState + Transform so the camera stays fixed. Includes camera, scene, stable component ID and exact named-action configuration.";
    }
    if (example.id === "runtime-component") {
      value.entities.push(
        {
          id: "camera",
          name: "Camera",
          enabled: true,
          parent: null,
          components: {
            "AdaTransform.Transform": transform(),
            "AdaRender.Camera": structuredClone(
              builtins.get("AdaRender.Camera").defaultPayload,
            ),
          },
        },
        {
          id: "reference",
          name: "Reference sprite",
          enabled: true,
          parent: null,
          components: {
            "AdaTransform.Transform": transform(),
            "AdaSprite.Sprite": {
              ...structuredClone(
                builtins.get("AdaSprite.Sprite").defaultPayload,
              ),
              size: { width: 80, height: 80 },
            },
          },
        },
      );
      files["Sources/Game.ada"] = `@component(id: "agent.example.counter")
struct Counter { @export var value = 0; }
@system(id: "example.spawn", scheduler: "startup")
class Spawn { func update(context) { context.world.commands.spawn([Counter(value: 0)]); } }
@system(id: "example.tick")
class Tick {
    @query(Counter) var counters;
    func update(context) {
        for (var row in counters) {
            row.counter.value += 1;
            if (row.counter.value % 60 == 0) print("counter=" + row.counter.value);
        }
    }
}`;
      example.description =
        "Complete browser AdaScript dynamic component with startup/update systems: spawns Counter data and reports counter values in Play logs every 60 updates. Includes an authored camera and static reference sprite for visible scene loading.";
    }
    files[scenePath] = JSON.stringify(value, null, 2);
    files[".ada/project.json"] = JSON.stringify(metadata, null, 2);
    example.platforms = ["web"];
    example.runtimeAPI = contract.runtimeAPI;
    example.assets ||= {};
    // Fail the export if adaptation accidentally leaves unsupported components.
    const sources = Object.entries(files)
      .filter(([name]) => name.startsWith("Sources/"))
      .map(([, content]) => content)
      .join("\n");
    for (const entity of value.entities)
      for (const name of Object.keys(entity.components)) {
        if (!builtins.has(name) && !sources.includes(`id: "${name}"`))
          throw new Error(
            `Unsupported example component: ${example.id}/${name}`,
          );
      }
    for (const entity of value.entities)
      for (const payload of Object.values(entity.components)) {
        for (const name of ["source", "texture", "map"]) {
          const ref = payload[name];
          if (typeof ref !== "string" || !ref.startsWith("@res://")) continue;
          const path = "Assets/" + ref.slice(7);
          if (!(path in files) && !(path in example.assets))
            throw new Error(`Missing example asset: ${example.id}/${path}`);
        }
      }
  }
  return examples;
}
