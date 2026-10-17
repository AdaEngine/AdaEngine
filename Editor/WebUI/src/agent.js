import { stream, decode, bytes } from "./platform.js";
import { file, template, validate, scene } from "./documents.js";
export async function runAgent(studio, text) {
  if (studio.running || !text.trim()) return;
  if (!studio.providerID || !studio.model?.tools) {
    studio.settings = true;
    studio.emit();
    throw new Error("Выберите модель с поддержкой инструментов");
  }
  if (studio.billingMode === "byok" && !studio.apiKey.trim()) {
    studio.settings = true;
    studio.emit();
    throw new Error("Введите API-ключ провайдера");
  }
  if (!studio.document)
    await studio.createSnapshot(template(3, text.slice(0, 60)));
  const document = studio.document,
    controller = new AbortController();
  studio.agent = controller;
  studio.running = true;
  studio.prompt = "";
  studio.activity = [];
  try {
    const answered = new Set(
      studio.snapshot.messages.map((m) => m.toolCallID).filter(Boolean),
    );
    for (const m of [...studio.snapshot.messages])
      for (const call of m.toolCalls ?? [])
        if (!answered.has(call.id))
          studio.append({
            role: "tool",
            toolCallID: call.id,
            content:
              "Interrupted previous tool. Inspect the current project; do not replay without checking.",
          });
    let content = text;
    if (studio.entity)
      content += "\n[Selected entity]\n" + JSON.stringify(studio.entity);
    if (studio.latestCodeSelection)
      content +=
        "\n[Selected code]\n" + studio.latestCodeSelection.slice(0, 8000);
    studio.append({ role: "user", content });
    studio.emit();
    for (let step = 0; step < 40; step++) {
      controller.signal.throwIfAborted();
      studio.streamText = "";
      const calls = [];
      let complete = false,
        failure;
      const groups = [];
      for (const m of studio.snapshot.messages) {
        if (m.role === "tool" && groups.length) groups.at(-1).push(m);
        else groups.push([m]);
      }
      let messages = [],
        budget = 0;
      for (const group of groups.reverse()) {
        const size = new TextEncoder().encode(JSON.stringify(group)).length;
        if (size + budget > 145000) break;
        messages = group.concat(messages);
        budget += size;
      }
      if (messages.length < studio.snapshot.messages.length)
        messages.unshift({
          role: "user",
          content:
            "Inspect the current project before making changes. Goal: " +
            text.slice(0, 4000),
        });
      await stream(
        {
          operationID: crypto.randomUUID(),
          providerID: studio.providerID,
          model: studio.modelID,
          billingMode: studio.billingMode,
          apiKey: studio.billingMode === "byok" ? studio.apiKey : undefined,
          messages,
          tools,
        },
        controller.signal,
        (event) => {
          if (event.type === "text") studio.streamText += event.text ?? "";
          if (event.type === "tool") calls.push(event.call);
          if (event.type === "complete") complete = true;
          if (event.type === "error") failure = event.message;
          studio.emit();
        },
      );
      controller.signal.throwIfAborted();
      if (failure || !complete)
        throw new Error(
          failure || "Ответ прерван. Можно продолжить с сохранённого шага.",
        );
      studio.append({
        role: "assistant",
        content: studio.streamText,
        toolCalls: calls.length ? calls : undefined,
      });
      studio.streamText = "";
      if (!calls.length) break;
      const images = [];
      for (const call of calls) {
        controller.signal.throwIfAborted();
        const entry = {
          id: call.id,
          name: call.function.name,
          status: "running",
        };
        studio.activity.push(entry);
        studio.emit();
        let result;
        try {
          result = await studio.runTool(
            entry.name,
            JSON.parse(call.function.arguments),
          );
          entry.status = "done";
        } catch (e) {
          result = { error: e.message };
          entry.status = "error";
        }
        controller.signal.throwIfAborted();
        if (studio.document !== document)
          throw new Error("Открыт другой проект");
        if (
          entry.name === "editor_play_capture" &&
          typeof result === "string" &&
          result.startsWith("data:image/")
        ) {
          studio.append({
            role: "tool",
            toolCallID: call.id,
            content: "Game frame captured.",
          });
          images.push(result);
        } else
          studio.append({
            role: "tool",
            toolCallID: call.id,
            content:
              typeof result === "string" ? result : JSON.stringify(result),
          });
      }
      if (images.length)
        studio.append({
          role: "user",
          content: "Current game frames",
          images: images.slice(-4),
        });
    }
  } catch (e) {
    if (!controller.signal.aborted) studio.fail(e);
  } finally {
    studio.running = false;
    studio.agent = null;
    studio.streamText = "";
    studio.emit();
    await studio.save(true);
  }
}
export async function runTool(studio, name, args) {
  switch (name) {
    case "editor_project_files":
      return studio.snapshot.files.map((f) => f.path);
    case "editor_file_read": {
      const f = file(studio.snapshot, args.path);
      if (!f) throw new Error("Файл не найден");
      if (bytes(f.data).length > 100000)
        throw new Error("Файл слишком велик для текстового контекста");
      return decode(f.data);
    }
    case "editor_file_write":
      studio.document.write(args.path, args.content);
      studio.changed();
      return "Saved " + args.path;
    case "editor_file_delete":
      studio.document.edit((s) => {
        s.files = s.files.filter((f) => f.path !== args.path);
      });
      studio.changed();
      return "Deleted";
    case "editor_scene_get":
      return studio.scene;
    case "editor_scene_set":
      studio.editScene((s) => {
        const e = s.entities.find((e) => e.id === args.entity);
        if (!e) throw new Error("Объект не найден");
        e.components[args.component] ??= {};
        e.components[args.component][args.field] = args.value;
      });
      return "Scene updated";
    case "editor_scene_add": {
      const id = crypto.randomUUID();
      studio.editScene((s) =>
        s.entities.push({
          id,
          name: args.name,
          enabled: true,
          parent: args.parent ?? null,
          components: args.components,
        }),
      );
      return id;
    }
    case "editor_build":
      try {
        validate(studio.snapshot);
        scene(studio.snapshot);
        await studio.play(true);
        return { diagnostics: "", runtime: "AdaPlayer API 4" };
      } catch (e) {
        return { diagnostics: e.message };
      }
    case "editor_play_start":
      await studio.play();
      return { running: studio.preview.ready };
    case "editor_play_stop":
      await studio.stop();
      return "Stopped";
    case "editor_play_logs":
      return studio.preview.message("logs");
    case "editor_play_input":
      return studio.preview.message("input", args);
    case "editor_play_capture":
      if (!studio.model?.vision)
        throw new Error("Модель не поддерживает изображения");
      return studio.preview.message("capture");
    case "editor_docs_read": {
      const response = await fetch("./recipes.md");
      if (!response.ok) throw new Error("Документация недоступна");
      return response.text();
    }
    default:
      throw new Error("Недоступный инструмент: " + name);
  }
}
const string = { type: "string" };
const tool = (name, description, properties = {}, required = []) => ({
  type: "function",
  function: {
    name,
    description,
    parameters: { type: "object", properties, required },
  },
});
export const tools = [
  tool("editor_project_files", "List project file paths."),
  tool("editor_file_read", "Read project text.", { path: string }, ["path"]),
  tool(
    "editor_file_write",
    "Write a project text file with document undo.",
    { path: string, content: string },
    ["path", "content"],
  ),
  tool("editor_file_delete", "Delete a nonessential file.", { path: string }, [
    "path",
  ]),
  tool("editor_scene_get", "Read scene entities and components."),
  tool(
    "editor_scene_set",
    "Set component field. Transform arrays use position XYZ, scale XYZ, rotation quaternion XYZW.",
    { entity: string, component: string, field: string, value: {} },
    ["entity", "component", "field", "value"],
  ),
  tool(
    "editor_scene_add",
    "Create entity.",
    { name: string, components: { type: "object" }, parent: string },
    ["name", "components"],
  ),
  tool(
    "editor_build",
    "Compile and validate the current scene with the isolated AdaPlayer.",
  ),
  tool("editor_play_start", "Run the game."),
  tool("editor_play_stop", "Stop game."),
  tool("editor_play_logs", "Read player logs."),
  tool("editor_play_capture", "Capture game camera."),
  tool(
    "editor_play_input",
    "Send bounded keyboard input.",
    { key: string, phase: string, durationMs: { type: "integer" } },
    ["key", "phase"],
  ),
  tool("editor_docs_read", "Read AdaScript syntax before editing gameplay."),
];
