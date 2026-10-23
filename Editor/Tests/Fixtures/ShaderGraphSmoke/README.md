# Shader Graph smoke project

Copy this directory to a writable location and open it as an ordinary AdaScript
project in Studio. No build cache, workspace state or prebuilt shader archive is
included. `Main.ascn` contains a Sprite and camera; its graph samples the supplied
2×2 checker and multiplies it by the exposed `tint`. `Main.ada` changes `tint`
through the real writable Sprite query API. `Surface.shadergraph` is a PBR graph
for opening in the editor or assigning to a primitive in a new 3D scene.

See [handoff commands and pending acceptance checks](../../../Documentation/ShaderGraphHandoff.md).
The fixture makes failures reproducible; it does not imply successful exported
Player playback on every target.
