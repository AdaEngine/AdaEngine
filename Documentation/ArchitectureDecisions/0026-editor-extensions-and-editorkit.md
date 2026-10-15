# ADR-0026: Editor extensions and AdaEditorKit

Status: Accepted.

Implementation: Partial (local foundation; not released).

## Context

ADR-0023 gives project-local AdaScript tools a `.ui` panel in the macOS right
sidebar. That is the only extension point of the editor. New document editors
(`EditorAssetPreviewKind`, `EditorProjectFileKind` and the `switch` in
`EditorCenterWorkbench`), inspector controls (`EditorComponentFieldKind`) and
viewport interaction are closed enumerations compiled into the app. A Godot-style
add-on, such as a terrain editor with a brush, its own resource type and an
inspector, cannot be written today.

Extensions must work on macOS, Windows, iPadOS, iOS and visionOS. Apple platforms
forbid loading downloaded native code, and the editor is an executable package,
so a native plugin cannot `import AdaEditor`.

## Decision

### 1. One location: `Tools/`

Every extension lives in the project's `Tools/<Module>/` directory, the same
directory as ADR-0023 tool modules. There is no second search path and no global
install in this slice. A project therefore carries its extensions, and opening it
on another machine or platform reproduces the same editor.

### 2. Contributions, not hooks

Extensions add behavior only by registering typed **contributions** with the
editor. The editor reads those registries instead of switching over closed
enumerations. The contribution kinds are:

| Contribution | Replaces / adds |
| --- | --- |
| `PanelContribution` | panels in the left, right and bottom areas, and a full **main screen** tab |
| `DocumentEditorContribution` | an editor for files by extension, a new resource type |
| `CommandContribution` | commands, menu items and shortcuts |
| `InspectorContribution` | a custom control for a component type |
| `ViewportToolContribution` | pointer and key handling in the scene viewport, with undoable strokes |
| `NewFileTemplateContribution` | entries in the New File menu |

Built-in editors (tile map, tile source, atlas, particles) migrate to the same
registries so the API is exercised by the product itself.

### 3. Two implementation tiers, one API

**AdaScript tools** are available on every platform, including iOS, iPadOS,
visionOS and Windows. They declare contributions through `@tool` metadata and
the scoped `editor` bridge from ADR-0023, with UI as `.ui` resources.

**Native extensions** are Swift types conforming to `EditorExtension`. They are
linked **statically** into an editor build, and are never downloaded or loaded
at run time. This keeps App Store platforms valid and avoids an ABI boundary.
Desktop and Windows editors may be built with additional extension packages. A
native extension reaches a project through its `Tools/` module, whose manifest
names the extension ID; if the running editor does not contain that ID, the
module is reported as unavailable instead of failing the project.

Both tiers register into the same `EditorExtensionRegistry`.

### 4. AdaEditorKit

`AdaEditorKit` is a new SwiftPM target and library product of the editor
package. It depends only on AdaEngine (AdaUI and Math), never on `AdaEditor`,
so an extension package can depend on it. It owns:

- `EditorExtension`, `EditorExtensionManifest` (ID, version, API version,
  supported platforms, requested permissions);
- the contribution types above;
- `EditorExtensionRegistry`, `EditorExtensionContext`;
- the host service protocol `EditorHostServices` (active document, undoable
  transactions) that `AdaEditor` implements.

The kit contains no platform conditionals beyond the platform enumeration, and
every public type is `Sendable` or `@MainActor`.

### 5. Ownership, validation and permissions

- Every registration is tagged with its owning extension. Deactivating or
  replacing an extension removes all of its contributions atomically. A failed
  activation registers nothing.
- Contribution IDs are unique across the registry. A duplicate is an error that
  names both owners; an extension never overrides another extension or a built-in.
- Activation is refused when the manifest API version is newer than the kit, or
  the current platform is not in the manifest's platform list.
- Contributions that read or write documents require a declared permission
  (`documents.read`, `documents.write`, `viewport.input`). A contribution whose
  permission was not declared is rejected at registration. The consent flow of
  ADR-0023 is reused for granting.
- Viewport tools mutate the scene only through `EditorHostServices.performTransaction`,
  so a brush stroke is one history step.

### 6. Platform adaptation

Contribution views are AdaUI `AnyView`s. Panels declare a **preferred** location;
the host remaps it where the area does not exist (compact iPhone layouts present
panels as sheets or tabs). Extensions must not depend on hover or a keyboard.
A viewport tool declares the input styles it supports (pointer, touch, pencil).

## Consequences

- A terrain editor becomes a document editor, an inspector contribution, a
  viewport tool and a panel, all registered through one `EditorExtension`.
- Native rendering and heavy tools stay out of Apple mobile platforms by
  construction. Scripted tools remain portable.
- The contribution registry is a public, versioned API. Changing it needs an
  API-version bump.
- A statically linked native extension has the privileges of the editor; the
  permission flag is a consent and review mechanism, not a sandbox. The ADR-0023
  note that the restricted VM is not a process sandbox applies equally here.

## Delivery stages

1. This ADR and the `AdaEditorKit` target with registry, validation and tests (done).
2. `EditorViewModel` owns a registry; Studio Tools registers its panels as
   `PanelContribution`s on every platform, not only the macOS sidebar.
3. Document editors: replace the asset-kind `switch` with registry lookup and move
   tile map/source/atlas/particles onto it.
4. Inspector contributions and extensible `EditorComponentFieldKind`.
5. Viewport tools, gizmo overlays and transactional strokes.
6. `Tools/` manifest for native extension binding; extension manager in Settings.
7. Reference extension: Terrain (resource, brush tool, inspector). The runtime
   terrain component and renderer are a separate engine ADR.
