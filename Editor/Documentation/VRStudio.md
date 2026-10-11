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
window sizing, panels, document tabs, voice, and **Enter Immersive**. Immersion
requires an editable scene and explicit entry. **Exit Immersive** returns to the
same Studio documents. Hierarchy, Inspector, Settings, Play, and other panels use
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
