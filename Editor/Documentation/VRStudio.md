# Ada Studio VR

The visionOS edition uses a native SwiftUI application entry point (`AdaStudioVRApp`),
with the shared AdaUI project chooser and workbench embedded in native windows.
It requires visionOS 26 or later.

Generate the Xcode project with `xcodegen generate --spec project.yml`, then run
**AdaStudio-VR** on Apple Vision Pro or visionOS Simulator. **AdaEditor-visionOS**
is an alias for the same application. Its display name is **Ada Studio VR**;
the release bundle identifier remains `org.adaengine.editor` so it updates the
existing Studio installation.

Open or create a project in the chooser. Studio exposes native ornaments for
window sizing, panels, document tabs, voice, and **Enter Immersive**. This button always enters **Full** immersion,
even after a prior Mixed session. The separate **Mixed** button enters passthrough
explicitly; both options also appear in the Project panel. Immersion
requires an editable scene and explicit entry. **Exit Immersive** returns to the
same Studio documents and the last normal window size. Manual resizing and the
Wide preset survive the compact dock. Editor / Agent in the top toolbar switches
the shared workspace on visionOS; editor panel/tab ornaments hide in Agent mode. Full immersion presents the virtual sky/environment with valid far depth.
Mixed immersion keeps the physical surroundings visible;
scene geometry occludes hands according to its depth. While the palm menu is
visible, its pixels always cover hands; normal hand depth occlusion returns when it closes.
The palm menu sits six centimeters toward the viewer from the tracked palm. Hierarchy, Inspector, Settings, Play, and other panels use
separate native windows backed by the shared editor models.

AdaScript projects build locally and run in a separate Play window. SwiftPM
projects can be edited; compiling them requires a desktop host. Window sizing,
text input, and clipping use the native host's viewport and display scale.
Interactive controls install system gaze hover regions; focused text inputs,
disabled controls, and clipped rows are excluded. Physical gaze, hand tracking,
voice recognition, and two-hand manipulation require Apple Vision Pro validation.

The implementation was recovered from the uncommitted `codex/ada-studio-vr`
worktree and integrated with the current editor, including Android destinations,
Agent Interface, A2UI, and the official examples chooser. Diagnostic launch routes
from that prototype are excluded from the production application.

Immersive gizmos scale with the eye viewport: axes span approximately ten percent
of its smaller dimension, with a 200-pixel minimum. Strokes, arrowheads, rotation
rings, center handles and hit regions share the same scale. Spatial drag conversion
uses the resulting world-units-per-pixel ratio; desktop gizmo sizing is unchanged.
