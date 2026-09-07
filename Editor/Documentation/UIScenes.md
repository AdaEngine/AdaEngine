# UI scenes

Create a **UI Scene** from the project browser's **New** menu. `.ui` files contain
versioned YAML and open in a dedicated designer. They are reusable AdaUI resources,
not entity scenes.

The palette inserts into the selected container. Compose with HStack, VStack,
ZStack, Grid and lazy stacks; use ScrollView around overflowing content. Drag a
hierarchy row vertically to reorder it, or drag right onto another row to nest it.
The inspector edits properties, bindings, actions and ordered modifiers. Select
**Add content from palette** on a background/overlay modifier to fill its content
slot. **Design** selects nodes; **Interact** runs the controls against preview data.
**YAML** exposes the source, including diagnostics for unresolved exports.

The root inspector declares inputs with types and preview defaults, and named
actions. Property **Value / Binding** switches between a literal and a data path.
If reads a boolean binding; ForEach reads an array and a stable `idKey`, exposing
its current object as `item`. View state survives reordering by ID. A UI node
includes another `.ui`, with explicit input and action mappings. Open that source
with **Open UI source**. Include cycles are errors.

## Runtime

```swift
let data = UIBindingContext(values: ["playerName": .string("Ada")])
data.on("startGame") { arguments in /* start the game */ }
let component = try UIComponent(
    ui: "HUD.ui", context: data, behaviour: .overlay,
    resourceRoot: assetsDirectory
)
```

`data.bind("playerName", to: ...)` connects a `Binding<UIValue>` to existing game
state. Contexts are main-actor isolated. Factories receive detached values,
bindings and scoped actions; they must not access a VM or mutate the ECS world
while constructing a View. Custom control event callbacks use `inputs.perform`.

Existing `UIComponent(view: MyView(), behaviour: .overlay)` remains supported.
AdaScript files use `try UIComponent(script: "Sources/HUD.ada", identifier: "HUD",
resourceRoot: projectDirectory)`. The identifier is required when the loaded
module has multiple @view declarations.

In an entity inspector, add **UI Component**, choose a source kind and path or
exported View identifier, and configure inputs. `.ascn` stores this reference.
For code that decodes entities outside the editor, insert a
`UIComponentRuntimeResource(UIComponentRuntime(resourceRoot: assetsDirectory))`
into the world before updating UI. Call `runtime.enableAdaScript(sourceRoot: ...)`
when the world also loads AdaScript files. Named game contexts are registered in
`runtime.contexts`; arbitrary Swift View instances and closures are not Codable.

Resource paths accept `@res://` (relative to the resource root), or paths relative
to the including `.ui`. Resources must stay inside that root. File watchers can
send `UISceneResourceChanged` through the view's event manager. Invalid updates
retain the last working tree and expose a diagnostic on the session.

## Explicit exports

Swift modules implement `UIExportProvider`, returning `UINativeViewDescriptor`
and `UINativeModifierDescriptor` values. Signatures declare stable IDs, versions,
parameter types, bindings, actions and content slots. Register the same descriptors
in the game's UICatalog. The editor reads `.ada/ui-exports.json`, builds native
providers using the existing Swift Preview builder, and verifies their compiled
signatures before activating them. Keep export providers outside executable entry
point files.

AdaScript exports use the manifest's `scripts` array with `source`, `identifier`
and `signature`. Parameters explicitly name stored properties. A parameter with
`isBinding: true` writes back after an action; internal @state is not automatically
exported. @previewable is independent of palette export. Exported script Views
can use `NativeView("Game.Badge", title: "Hello")` with the same catalog, and
`.nativeModifier("Game.Modifier", ["amount": 2])` for exported modifiers.

Swift factories must be compiled into the host on iPadOS. Desktop SwiftPM
projects can build their exports locally; portable AdaScript projects cannot
compile arbitrary Swift sources on iPadOS.

See [the inventory example](../../Documentation/Examples/UIScenes) for Grid,
ForEach, a nested ItemCard.ui and an explicitly exported Swift badge. The example
is a SwiftPM library that can be opened in the editor or linked into a game.
