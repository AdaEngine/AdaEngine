---
name: ada-render-shaders
description: Rendering, backends, materials, and shader toolchain work in AdaEngine. Use when modifying AdaRender, GPU resources, render pipelines, shader compilation, reflection, or shader assets (GLSL/SPIR-V, caches, backend-specific code).
---

# Ada Render Shaders

## Overview
Handle AdaEngine rendering and shader pipeline tasks across AdaRender and its shader toolchain. Prefer AdaRender abstractions and touch backend-specific code only when the change truly requires it.

## Key Areas
- `Sources/AdaRender/Backends` for Metal/Vulkan/WebGPU/OpenGL backends and command encoders.
- `Sources/AdaRender/Shaders` for compiler, cache, reflection, and shader module wiring.
- `Sources/AdaRender/Assets/Shaders` for GLSL sources and shared include files.
- `Sources/AdaRender/Materials`, `Sources/AdaRender/Mesh`, `Sources/AdaRender/RenderGraph` for pipeline configuration and render flow.
- `Sources/SPIRVCompiler`, `Sources/SPIRV-Cross`, `Sources/glslang` for vendor toolchain code.

## Workflow
1. Identify the target backend and render path before changing code.
2. If the change is shader-related, update GLSL in `Sources/AdaRender/Assets/Shaders` and verify includes and entry points.
3. If the change is compilation or reflection-related, update `Sources/AdaRender/Shaders` and keep cache behavior consistent.
4. If the change is pipeline-related, update materials, vertex descriptors, or render graph code and keep API usage consistent.
5. Avoid editing vendored sources unless absolutely required.

## Guardrails
- Keep platform conditionals intact (`METAL`, `WGPU_ENABLED`, `DARWIN`, etc.).
- Preserve shader cache behavior in `ShaderCache` unless the change explicitly requires a cache version bump.
- Keep GPU resource types Sendable only when safe and document `@unchecked Sendable` uses.
- Prefer minimal, localized changes over sweeping backend refactors.

## Testing
- Run `swift build` for compile validation.
- Run `swift test --parallel --filter AdaRenderTests` when touching render code.
