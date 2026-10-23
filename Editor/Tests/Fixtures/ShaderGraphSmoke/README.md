# Shader Graph smoke project

Copy this directory to a writable location and open it as an ordinary AdaScript
project in Studio. No build cache, workspace state or prebuilt shader archive is
included. `Main.ascn` contains a Sprite and camera; its graph samples the supplied
2×2 checker and multiplies it by the exposed `tint`. `Main.ada` changes `tint`
through the real writable Sprite query API.

`PBR.ascn` contains Quad, Circle, Cube, Sphere and Plane graph materials, a shadow
receiver, a sun and two instances of an imported model with independent material
overrides. `LayeredCrate.gltf` derives from the repository's SkeletalGardenAssets
`Crate.glb`, embeds its mesh buffer and references the supplied checker through
relative paths. Its material enables all clearcoat/sheen/anisotropy/specular layer
textures, exercising the host baker's texture and layer variants.

For the PBR run, set `.ada/project.json` runtime plugin preset to `game3d`, and
runtime entry scene plus editor startup scene to `Assets/Scenes/PBR.ascn`. Copy
`Examples/PBR.ada` into `Sources/PBR.ada`. That script reads `Transform.position`
and the graph's parameter type through the real AOT host bridge, then changes
primitive roughness from 0.15 to 0.85. The two imported materials retain their
different tints and the graph's default roughness. A `roughness` debug view can distinguish
the script's result from the graph default.

See [handoff commands and pending acceptance checks](../../../Documentation/ShaderGraphHandoff.md).
The fixture makes failures reproducible; it does not imply successful exported
Player playback on every target.
