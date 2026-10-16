# Spine 2D in Studio

Import a Spine 4.2 `.skel` or JSON export with **Import Assets**, or drop it into
the project. Keep its `.atlas` and texture pages beside the export. Studio copies
the full bundle into a new folder without replacing earlier imports; JSON exports
become `.spine` assets. A uniquely named atlas beside an export is also accepted.

Open the skeleton asset to view the native animation. Select a clip or skin,
use Play/Pause, and toggle Show/Hide bones. Bone geometry comes from the animated
runtime hierarchy and is drawn by AdaEngine above the character. Pausing and
toggling bones preserve playback time.

Use **Add to Scene** to place the character, or create **2D → Spine Character 2D**
and choose its skeleton in the Inspector. The **Spine 2D** component stores the
asset reference, clip, skin, autoplay, loop, speed and bone visibility. Settings
use normal scene history and Save; edit mode and scene Play share the native
Spine renderer. New characters use scale 0.005 to convert export pixels into
scene units; adjust Transform for the project's scale.

This is a viewer and scene integration. Author bones and skeletal keyframes in
Spine and re-export. The optional runtime's license is documented in
[Spine2D](../../Documentation/Spine2D.md). Public Community/mobile/Web player and
AdaScript export support are separate from this editor integration.

For imported 3D models, **Show bones** in the model viewer or 3D scene toolbar
shows existing skin joints and their hierarchy over the mesh. Bones follow the
current animation, including rest pose and paused playback. Helper nodes are
skipped when connecting joints, while their transforms remain part of the pose.
Models without a skin have no skeleton overlay; this does not generate a new rig.
