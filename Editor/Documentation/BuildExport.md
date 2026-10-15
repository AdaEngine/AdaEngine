# Build & Export settings

Open **Settings → Build & Export** to configure tools for the current computer.
These preferences apply across projects; paths are not written into `.adaproject`.
Use **Browse…** for files/directories and **Save Build Settings** to persist edits.
Empty fields use automatic discovery. Path labels check availability, not compiler
versions or successful game builds. External tools require standalone desktop Studio.

Each page has **Rescan** and scans once when first opened. Discovery fills empty
or unavailable paths; working overrides and edits made during a scan are kept.
Use **Save Build Settings** to apply the results. On Windows the scan rereads the
user and system environment from the registry, so tools installed after Studio
started can be found without restarting it. It also checks standard versioned
Swift installations, Android SDK locations, Android Studio's JDK, SDK build-tools
and side-by-side NDKs, CMake, Ninja and Visual Studio build tools. A directory alone
does not establish availability: Android SDK needs adb, JDK needs javac, and NDK
needs its installation metadata. Discovery does not validate compiler versions.

**Install Swift…** on the host platform page opens the official Swift installation
instructions for this OS. **Install Android SDK…** on Android opens Google's
Android Studio setup page. These are guided browser flows, not unattended
installers. Finish installation there, then return to **Rescan** and save.
In Android Studio's SDK Manager, install Platform-Tools, Build-Tools, Emulator and
NDK (Side by side) as needed. An Android emulator still needs an AVD created in
Android Studio. Rescan does not download packages or accept license agreements.

Windows Web and Android builds run through WSL Ubuntu. Run
`script/setup_windows_build_tools.ps1` once to install the managed Linux cross
toolchains. Keep Web's Swift override empty to use the matching managed compiler;
an explicit override must be a Linux executable path. Android discovery and
deployment use the native Windows SDK, while the worker supplies Linux Swift,
SDK/NDK, JDK and Dawn. Native host compiler settings continue to select Windows Swift.

| Page | Tools and current use |
| --- | --- |
| Android | SDK, NDK, JDK, optional Gradle, build-tools version, emulator data, Swift Android SDK/toolchain and Swan/Dawn. Existing APK export and device/emulator Run consume these settings. |
| iOS | Swift, Xcode Developer directory and iOS SDK. Profile storage and path checks are available; Studio does not yet export iOS games. |
| Web | Swift WASM compiler, Swift SDK identifier and optional Tint. Web Run/Export consume these settings. |
| Windows | Swift, CMake, Ninja, Windows SDK and MSVC tools. Native host build commands consume the profile on Windows. Packaging Windows games from macOS is not available. |
| Linux | Swift, CMake, Ninja and C compiler. Native host build commands consume the profile on Linux. Packaging Linux games from macOS is not available. |
| macOS | Swift, Xcode Developer directory, SDK, CMake and Ninja. Native SwiftPM builds/runs/tests and macOS AdaScript export consume these settings. |
| VR / XR | Swift, Xcode Developer directory and visionOS SDK. Profile storage and path checks are available; XR export and other VR runtimes are not yet integrated. |

Android retains the existing `AdaStudio.Android.Tools` preference key. JDK home
affects Java/signing tools; Gradle is optional because the built-in APK exporter
uses Android tools directly. See [Android setup](Android.md).

Changing a native Swift compiler also uses its sibling SourceKit-LSP when present
on subsequent toolchain discovery. Reopen the project to refresh an already-running
language server. Web and Android tools have separate profiles and do not override
the native project compiler.
