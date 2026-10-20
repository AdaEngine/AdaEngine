# Shader Graph implementation status

The approved feature is being implemented in small increments. The current
increment supplies the portable graph format, asset-system envelope, validation
and typed intermediate representation in `AdaRender`. It does **not** generate
shader code, render a graph material or expose a Studio graph-editing tab yet.
Track later increments in the [decomposition map](../docs/tbd/decompositions/2026-10-20-shader-graph.md).

## Core API

```swift
import AdaRender

let graph = ShaderGraph(target: .sprite, output: "output", nodes: [
    .init(id: "tint", operation: .constant, type: .color, value: [1, 0.5, 0, 1]),
    .init(id: "output", operation: .output, inputs: ["color": .init("tint")])
])
let program = try graph.lowered()
```

`ShaderGraph` is a `Codable`, `Hashable`, `Sendable` value with no GPU or editor
dependency. `ShaderGraphAsset` wraps it for ordinary `AssetsManager.save` and
`loadFresh` calls using the `.shadergraph` extension. It uses the existing text
asset codec (YAML on native hosts, JSON on WASM); graph values also round-trip
directly through standard Codable encoders. Asset metadata belongs to the envelope
and is never serialized into the authored graph.

The file carries a required schema `version`, `target`, output-node ID, node
array and optional layout dictionary. Nodes carry stable IDs, operation `kind`,
value `type`, numeric `value`, optional `reference` and named input links. Links
name the source node and output port. All of these identifiers are independent
of the app language. Unsupported schema versions are rejected before decoding
the rest of the document. Unknown operation names remain readable as strings;
lowering rejects them with the responsible node ID. Consumers must preserve the
original file when they cannot understand it.

## Types and ports

- Values: Float, Bool, Vector2/3/4, linear RGBA Color and Texture2D.
- Numeric constants/defaults have exactly the type's component count and finite
  values. Bool uses one component, exactly `0` or `1`.
- `constant` and `parameter` output `value`. An exposed parameter's `reference`
  is its stable parameter ID; nodes sharing that ID must agree on type/default.
  A texture parameter has no numeric default.
- `texture` outputs `value` of type Texture2D; its `reference` is a resource path.
- `uv` outputs Vector2 `value`; `sampleTexture` consumes `texture` and `uv`,
  and outputs Vector4 `value`, Color `color`, Vector3 `rgb` and Float `alpha`.
- `add`/`multiply` consume `a`/`b`; `lerp` also consumes Float `t`.
- Sprite output accepts Color `color` and Float `alpha`. PBR output accepts Color
  `baseColor`, Vector3 `normal`/`emission` and Float `metallic`, `roughness`,
  `occlusion` and `alpha`. Unconnected output ports remain absent in IR so the
  target's eventual shader template can supply its defaults.

`lowered()` checks all authored nodes, including unused ones, and returns
structured `ShaderGraphDiagnostic` errors with a code, node/port identity and
expected/actual types when applicable. It rejects missing/duplicate IDs, missing
or multiple outputs, unknown operations/ports, dangling links, invalid payloads,
type mismatches and cycles. Float-to-vector/color broadcasts are explicit IR
conversions. Vectors of different dimensions, colors and vectors, and resources
never implicitly convert between each other.

The IR contains only reachable instructions, ordered dependencies before users.
Node array order, dictionary insertion order, unused computations and the entire
layout section cannot change the result. Cycle checking and ordering use an
iterative traversal so deep graphs do not consume the Swift call stack.

## Verification

`ShaderGraphTests` covers file and asset-manager round trips, typed links,
determinism, pruning, broadcasts, diagnostics, texture ports and a deep shared
graph. Run it from the engine root with `swift test --filter ShaderGraphTests`.
Rendering, backend shader compilation and Studio UI acceptance belong to later
increments; this suite is not evidence of those capabilities.
