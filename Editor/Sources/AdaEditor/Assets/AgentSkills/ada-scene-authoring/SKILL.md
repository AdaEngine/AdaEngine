---
name: ada-scene-authoring
description: Create and edit Ada scene entities, hierarchy, components, and scriptable objects safely.
allowed-tools: files.read, files.write, entity.find, component.get, render.capture_screenshot
---

# Ada Scene Authoring

- Inspect the active scene, selected entity, component descriptors, and asset references before editing.
- Prefer structured scene operations when available. If direct YAML editing is required, preserve `format`, `schemaVersion`, editor state, stable entity IDs, and unknown component payloads.
- Keep parent relationships acyclic. Add required components before dependent components.
- Validate the decoded scene, open it in the editor, and run it when the requested behavior is executable.
- Finish visual scene work with a screenshot of the relevant viewport or runtime window and inspect the result.
