---
name: ada-assets
description: Import, generate, configure, and connect image assets inside an AdaEngine project.
allowed-tools: files.read, files.write, asset.find, asset.get, render.capture_screenshot
---

# Ada Assets

- Resolve the project's declared resource roots and reuse existing assets before generating duplicates.
- Keep generated or imported files under a resource root and return their project-relative path and `@res://` reference.
- Never overwrite an existing asset without explicit approval. Validate image data before saving it.
- When an asset is meant for a scene, connect it to the requested entity and component field rather than stopping after file creation.
- Rebuild or reload the owning scene and inspect a screenshot to verify scale, transparency, framing, and reference resolution.
