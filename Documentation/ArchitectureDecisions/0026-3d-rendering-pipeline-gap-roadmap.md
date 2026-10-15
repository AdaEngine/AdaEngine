# ADR-0026: 3D rendering pipeline gap analysis and roadmap

- Status: Proposed
- Date: 2026-10-16
- Implementation: Planned

## Context

ADR-0017 through ADR-0021 and ADR-0025 define the current 3D direction. This
ADR records what the 3D pipeline still lacks after a source audit, groups the
gaps into independently shippable stages, and states how they relate to the
existing ADRs. It adds no behavior by itself. Where an existing ADR already
owns a gap, this ADR links to it instead of redefining it.

The audit covered `AdaCorePipelines`, `AdaRender`, the native glTF loader in
`AdaAssets`, `AdaScene/3D` and the existing tests. Absence claims below come
from source search and may miss code behind unconventional names; each stage
must re-verify its own premise before implementation starts.

### What exists today (not gaps)

- **Graph.** `Core3DPlugin` builds a fixed forward graph: directional shadow,
  local shadow, `Main3D` (PBR), SSAO, SSR, anti-aliasing, temporal resolve with
  tone mapping, optional `Scene2D`, upscale. There is no depth/normal prepass
  and no deferred path; SSAO and SSR consume depth and normals produced
  after the main pass.
- **Lighting.** Metallic-roughness PBR; up to 4 directional and 32 local lights
  per frame, with 4 shadow-casting lights and a per-camera shadow atlas budget
  (ADR-0018); cascaded directional shadows; baked IBL and a procedural or
  textured skybox with starfield; SSR.
- **Tone mapping.** A fixed ACES-fit curve followed by the sRGB transfer inside
  the temporal resolve shader. There is no exposure input.
- **Batching.** Opaque meshes are batched by mesh/material/skin key and drawn
  with per-instance data and `instanceCount`. Blended meshes are not merged and
  are depth sorted in `Main3DRenderNode`.
- **Visibility.** CPU frustum, distance and LOD culling; Metal GPU Hi-Z
  occlusion with indirect draw (ADR-0020).
- **Skinning and animation.** GPU skinning, skeletal animation graphs, animation
  LOD, motion vectors for camera, rigid and skinned meshes (ADR-0017).
- **Assets.** Native glTF import with PBR metallic-roughness, `KHR_mesh_quantization`
  and `KHR_materials_emissive_strength`; voxel import and meshing (ADR-0025).
- **Backends.** Metal is the reference backend; native WebGPU is validated for
  lighting and shadows (ADR-0018). Vulkan and OpenGL backends exist.

### Gaps

Gaps already owned by another ADR are marked with their owner.

**G1. Post-processing is not a stack.** No exposure, bloom, depth of field,
motion blur, color grading or vignette. The only post chain is hard-wired
graph nodes. Owner for exposure and bloom: ADR-0019.

**G2. Materials are the base glTF PBR set only.** `PBRMaterial` has no
clearcoat, transmission, volume, IOR, specular, sheen, anisotropy or UV
transform. The loader accepts exactly two extensions and rejects others it
does not know. `KHR_lights_punctual` is not imported.

**G3. No morph targets.** Neither the importer nor the runtime has blend
shapes. This blocks facial animation, corrective shapes and many character
assets.

**G4. Transparency is sort-only.** Blended meshes are depth sorted per object.
Intersecting or large transparent meshes produce ordering artifacts. There is
no order-independent transparency and no transmission or refraction pass for
PBR.

**G5. No atmosphere or volumetrics.** No distance or height fog, no physical
sky, clouds, volumetric fog or light shafts. Reflections of the sky outside SSR
range depend only on baked IBL. Planar reflections are absent.

**G6. Lighting scale and quality.** Lights are evaluated by a flat loop over
the per-frame light list (not clustered or tiled). Missing: contact shadows,
soft penumbra shadows, area lights, light cookies/IES profiles. Probes,
lightmaps and unified reflection composition are owned by ADR-0019; ray traced
reflections by ADR-0021. There is no dynamic GI.

**G7. Scene content features.** No decals, terrain, water, foliage/wind or
GPU particles in 3D. Static meshes have no automatic LOD generation; ADR-0020
LOD covers skinned meshes and animation cadence. Hi-Z occlusion and indirect
draw exist only on Metal (ADR-0020 notes this as a backend extension).

**G8. Renderer introspection and regression safety.** The command encoder has a
wireframe fill mode, but there are no 3D debug views (normals, depth, overdraw,
shadow cascades, light heat map), no runtime GPU timing overlay, and no
user-facing 3D debug-draw API. Existing 3D tests exercise extraction,
scheduling, history and budgets in code; none compares rendered frames to
reference images, so visual regressions rely on manual captures recorded in
ADRs.

**G9. Platform parity.** TAA/MetalFX proof on Apple mobile and non-Metal
fallbacks is unrecorded (ADR-0017). Several passes (Hi-Z, indirect draw, SSR,
SSAO) are only proven on Metal.

## Decision

Close the gaps in the stages below. Each stage ships behind its own
checklist item with recorded validation, and stages may be reordered when a
dependency is satisfied. Prefer extending the existing render graph, ECS
extraction and `Environment3D`/camera settings over parallel systems. Keep
scene color linear HDR until the final output transform. UI stays outside 3D
post-processing and exposure.

### Stage 0. Foundations

These unblock later stages and make their results verifiable.

1. **Debug views and diagnostics.** Add per-camera debug view modes: wireframe,
   normals, depth, albedo/roughness/metallic, overdraw, shadow cascade tint and
   light-count heat map. They are developer features, off by default, and add
   no cost to the normal path. Expose GPU pass timings next to the existing
   `Render3DPerformanceMetrics`. Add a small 3D debug-draw API (lines, boxes,
   spheres, frusta, axes) with a lifetime in frames.
2. **Golden-frame tests.** Add a headless render-and-compare harness for
   deterministic scenes (PBR spheres, shadows, skybox, transparency). Compare
   against stored references with a documented tolerance per backend. Native
   Metal is the reference; other backends record their own tolerances.
3. **Shared depth/normal prepass.** Decide with measurement whether a prepass
   improves SSAO, SSR, decals and contact shadows enough to justify its cost. If
   adopted, expose depth and normals as render-graph resources so later effects
   do not each re-render geometry. If rejected, record the measured reason.

### Stage 1. Post-processing stack

ADR-0019 owns manual exposure and HDR bloom. This stage generalizes that work.

- Introduce per-camera post-process settings (a component or `Environment3D`
  extension) with ordered, individually toggled effects and a defined order:
  exposure/auto-exposure, bloom, depth of field, motion blur, color grading,
  tone mapping, vignette/grain, then anti-aliasing/upscale as already ordered by
  ADR-0017.
- Make tone mapping an operator choice (at minimum the current ACES fit, a
  neutral operator and none) with exposure applied before it. The default must
  reproduce current output for existing scenes.
- Add auto-exposure (histogram or average-luminance, with adaptation speed and
  min/max EV) after manual exposure is stable.
- Add depth of field and per-object/camera motion blur using the existing
  motion vectors; both are bounded by quality settings and disabled on devices
  that cannot afford them.
- Add 3D LUT color grading with an asset type and Editor preview.
- Reuse downsample/upsample targets across effects through render-graph
  resources; effects that are off allocate nothing.

### Stage 2. Materials and glTF import

- Extend `PBRMaterial` additively with optional extension blocks so existing
  materials, scene payloads and shaders decode and render identically. Order of
  implementation by value: `KHR_texture_transform`, `KHR_materials_ior`,
  `KHR_materials_specular`, `KHR_materials_clearcoat`,
  `KHR_materials_transmission` and `KHR_materials_volume` (see Stage 4),
  `KHR_materials_sheen`, `KHR_materials_anisotropy`. Import
  `KHR_lights_punctual` into the existing light components.
- The loader keeps rejecting extensions marked `extensionsRequired` that it
  does not support. Extensions listed only in `extensionsUsed` and not
  supported must degrade to the base material and report a warning, not fail.
  Maintain the supported list in one place and document it.
- Material variants must not multiply pipeline permutations unboundedly: add
  features through uniform data and bounded shader keys, and measure shader
  compile count and pipeline cache size.
- Add an Editor inspector for the new fields and update the
  `ada-3d-materials` agent skill.

### Stage 3. Morph targets

- Define a morph-target asset: per-primitive position/normal/tangent deltas,
  default weights, and target names. Import from glTF `targets` and `weights`,
  including animated `weights` channels.
- Evaluate on the GPU with sparse or compacted deltas and a hard limit on
  active targets per mesh (for example 8), selecting the highest weights. Combine
  correctly with GPU skinning (morph first, then skin).
- Keep motion vectors, shadow pass geometry and bounds correct for morphed and
  morphed-plus-skinned meshes; conservative bounds must cover the maximum
  displacement.
- Integrate with keyframe animation and the animation graph as animatable
  weights, and expose weights to AdaScript and the Editor.

### Stage 4. Transparency

- Add order-independent transparency as an opt-in camera/material mode for
  blended PBR, choosing between weighted blended OIT (cheap, approximate) and a
  per-pixel list technique after measuring on Metal and WebGPU. Keep the
  existing sorted path as the default and fallback.
- Add a transmission pass: render opaque scene color to a mip-chained
  texture, sample it through roughness-dependent blur and IOR-driven offset for
  `KHR_materials_transmission`/`volume` materials. Transmissive surfaces do not
  see other transmissive surfaces in the first version; document that limit.
- Define how shadows are cast by blended materials (alpha-masked casting
  already exists per ADR-0018) and how SSR/SSAO treat them.
- Clarify the relationship with the existing `GlassRenderPipeline`, which
  renders screen-space glass quads: it is not PBR transmission, and neither
  replaces the other without a separate decision.

### Stage 5. Atmosphere, fog and volumetrics

- Add distance and height fog to `Environment3D`, applied in linear HDR before
  tone mapping, with color, density, falloff and optional sun in-scattering.
- Add a physically based sky (precomputed transmittance and multi-scattering
  LUTs, driven by the primary directional light) as an alternative to the
  gradient/texture skybox, plus a time-of-day driver. Sky must feed IBL so
  ambient lighting follows it; define a bounded update cost.
- Add froxel volumetric fog and light shafts for directional and shadowed local
  lights, opt-in and quality-scaled. Cloud rendering is a separate follow-up.
- Add planar reflections for water and mirrors with a bounded extra-render cost
  and clear integration with the ADR-0019 reflection composition contract.

### Stage 6. Lighting scale and quality

- Replace the flat per-frame light loop with clustered (or tiled) forward light
  assignment once lights routinely exceed the current loop's budget, measured
  against the 32-light limit. Raise limits only with evidence.
- Add screen-space contact shadows for small-scale detail and percentage-closer
  soft shadows with light-size-driven penumbra for directional and spot lights.
- Add rectangular/tube area lights (LTC) and light cookies/IES profiles for spot
  and directional lights.
- Probes, baked indirect lighting and reflection composition stay in ADR-0019;
  ray tracing stays in ADR-0021. Dynamic GI (SSGI or probe grids) is deferred
  until probes ship and a scene needs it. Virtual shadow maps are deferred
  until cascades demonstrably fail on target scenes.

### Stage 7. Scene content features

Each item needs its own short requirements note before implementation.

- **Decals.** Projected box decals with albedo, normal and roughness, depth
  and normal aware, clustered with lights if Stage 6 lands.
- **Instancing and LOD.** Static-mesh LOD generation and selection in the import
  pipeline, using the ADR-0020 visibility contract. Extend instancing to
  blended meshes only if Stage 4 makes this meaningful. Meshlets/mesh shaders
  are explicitly deferred.
- **Terrain and water.** Heightmap terrain with tiled LOD and splat materials;
  water surface with reflection, refraction and depth fade, built on Stages 4
  and 5.
- **Foliage.** Instanced vegetation with wind animation, distance fade and
  alpha-to-coverage.
- **3D particles.** GPU particles with lit and unlit modes, soft depth fade,
  and depth sorting that cooperates with Stage 4. Particles need their own
  requirements, as ADR-0022 already states for 2D.
- **Backend parity.** Implement Hi-Z occlusion and indirect draw on WebGPU and
  Vulkan, or document a measured CPU fallback as the permanent contract.

### Stage 8. Platform parity and budgets

- Record the TAA/MetalFX Apple mobile and non-Metal results required by
  ADR-0017.
- For every new effect, define a quality tier, a backend capability check, a
  safe fallback and a GPU/memory budget. An unsupported device must degrade
  visibly to the previous behavior, not fail.
- Keep WebGPU pixel validation (`script/validate_webgpu.sh`) in the checklist
  for any shader change that must run on the web.

## Non-goals

- A deferred or visibility-buffer renderer. Revisit only if clustered forward
  proves insufficient with measurements.
- Replacing the render graph or the Metal-first backend strategy.
- Dynamic global illumination, ray traced GI/shadows and virtual geometry. The
  first remains deferred (ADR-0019); ray tracing is ADR-0021.
- Expanding the glTF extension set beyond those listed in Stage 2 without a
  real asset needing it.

## Priority order

1. Stage 0 (diagnostics and golden frames), so everything after it is verifiable.
2. Stage 1 exposure and bloom (ADR-0019), then the rest of the post stack.
3. Stage 3 morph targets and Stage 2 material extensions (asset correctness).
4. Stage 5 fog and sky, then Stage 4 transparency.
5. Stage 6 clustered lights and shadow quality, then Stage 7 content features.
6. ADR-0019 probes and ADR-0021 ray tracing as already ordered by their ADRs.
7. Stage 8 runs continuously alongside each stage.

## Implementation checklist

- [ ] Stage 0: debug views, GPU pass timing, and 3D debug-draw API.
- [ ] Stage 0: golden-frame harness with recorded per-backend tolerances.
- [ ] Stage 0: prepass decision recorded with measurements.
- [ ] Stage 1: per-camera post-process stack with exposure and tone-map operators (ADR-0019 exposure).
- [ ] Stage 1: bloom (ADR-0019), auto-exposure, color grading LUT, vignette.
- [ ] Stage 1: depth of field and motion blur with quality tiers.
- [ ] Stage 2: `KHR_texture_transform`, IOR, specular and clearcoat material extensions.
- [ ] Stage 2: sheen, anisotropy and `KHR_lights_punctual` import.
- [ ] Stage 2: unsupported-extension degradation policy and documented supported list.
- [ ] Stage 3: morph-target asset, glTF import and GPU evaluation.
- [ ] Stage 3: morph with skinning, shadows, motion vectors, bounds and animation weights.
- [ ] Stage 4: OIT mode with sorted fallback.
- [ ] Stage 4: transmission/volume pass.
- [ ] Stage 5: distance/height fog.
- [ ] Stage 5: physically based sky feeding IBL and time-of-day driver.
- [ ] Stage 5: volumetric fog and planar reflections.
- [ ] Stage 6: clustered or tiled light assignment with measured limits.
- [ ] Stage 6: contact shadows, soft shadows, area lights and cookies.
- [ ] Stage 7: decals, static-mesh LOD, terrain, water, foliage, 3D particles (each with its own requirements note).
- [ ] Stage 7: Hi-Z/indirect-draw parity on WebGPU and Vulkan or documented fallback.
- [ ] Stage 8: Apple mobile and non-Metal proof for TAA and the new effects.

## Validation requirements

Use Swift Testing for logic (settings decoding, extension gating, budgets,
history reset, ordering) and the Stage 0 golden-frame harness for pixels. Every
visual change records a native capture on at least Metal; web-targeted shaders
also record `script/validate_webgpu.sh` results. Record separately: source
tests, native GPU pixels and other-platform coverage.

Per stage, additionally verify:

- **Post stack:** disabled effects change no pixels and allocate nothing;
  existing scenes render identically at default settings; UI is unaffected by
  exposure and bloom; multiple cameras keep independent settings and history.
- **Materials/glTF:** old scenes and payloads decode and render unchanged;
  Khronos sample models for each extension match reference renders within
  tolerance; unsupported required extensions fail with a clear error.
- **Morph targets:** zero weights are bit-identical to the unmorphed mesh;
  morph plus skin, shadows and motion vectors agree with a CPU reference.
- **Transparency:** intersecting blended meshes show no ordering artifacts in
  OIT mode; fallback matches current behavior; transmission handles roughness
  and IOR cases without NaNs or negative colors.
- **Atmosphere:** energy is conserved across sun angles; fog and sky do not
  shift tone-mapped output of scenes with them disabled; sky-driven IBL updates
  stay within the stated budget.
- **Lighting scale:** clustered assignment matches the flat loop output on a
  reference scene; record frame time and memory at 8, 32 and above-limit light
  counts.
- **Content features:** each reports CPU time, GPU time, upload bytes and
  memory on a realistic scene, per ADR-0022's rule that fewer draw calls or
  allocations alone are not an improvement.

## Consequences

This ADR is a proposed roadmap, not evidence of shipped behavior. It becomes
Accepted when the owner confirms the priority order. Stage items that overlap
ADR-0017, ADR-0019, ADR-0020 and ADR-0021 are tracked in those ADRs'
checklists; update both places when one changes. Large stages (Stage 5, 6 and 7)
should be split into their own ADRs when design work begins, and this ADR
should then link to them and keep only the summary.
