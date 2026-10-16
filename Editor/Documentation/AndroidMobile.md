# Ada Studio Mobile for Android

The Android host runs the shared mobile AdaUI project browser, Build/chat,
files/code, scene editor, Play, settings, sessions and Community screens. Games
use the existing embedded AdaScript runtime; Swift projects still require the
standalone desktop distribution.

`Editor/Platforms/Android/StudioActivity.java` extends the engine NativeActivity
with IME text input, keyboard avoidance, Back navigation, the system document
picker, speech recognition, speech output and browser authentication. Agent and
Cloud credentials are encrypted with an Android Keystore AES-GCM key. Backups
are disabled for this host so encrypted preferences are not restored without
their device key.

## Build

Use the matching Swift toolchain, Swift Android SDK, NDK, Android SDK, JDK and
Android Dawn artifact described in [the engine setup](../../Tools/Android/README.md).
Build on Linux (including WSL) or macOS. Also provide the portable agent package:

```sh
export SLOPPY_RUNTIME_LOCAL_PATH=/path/to/Sloppy/Packages/SloppyRuntime
export ADAENGINE_SWAN_PACKAGE_PATH=/path/to/swan
export SWAN_LOCAL_DAWN=Dawn/dist/android.artifactbundle
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_NDK_HOME=/path/to/android-ndk

python3 Editor/Platforms/Android/studio.py doctor --swift /path/to/swift
python3 Editor/Platforms/Android/studio.py build --swift /path/to/swift
python3 Editor/Platforms/Android/studio.py run --swift /path/to/swift --serial emulator-5554 --abi x86_64
```

`studio.py` selects `ADAEDITOR_ANDROID=1`, the `AdaStudioMobile` dynamic library,
`org.adaengine.studio.StudioActivity`, the browser callback
`adaeditor://cloud/callback`, and a separate `.build-android-studio` cache/output.
The default ABI is ARM64; select x86_64 for an Intel emulator or `all` for both.
The Android Dawn bundle must contain every selected ABI. The existing packaging
tool compiles Java with `javac` and D8; Gradle is not required.

The development APK is `.build-android-studio/apk/AdaStudioMobile-debug.apk`.
For manual ADB installation, use `adb install --no-incremental -r <apk>`;
large debug libraries can time out when loaded through ADB incremental installs.
The `run` command already disables incremental installation.
To install a previously built APK, pass `run --apk /path/to/the.apk` with the
device serial. Preserve its debug keystore for updates without uninstalling.
Apple and desktop builds keep the ordinary `AdaEditor` executable product when
`ADAEDITOR_ANDROID` is unset.

The portable agent packages are copied into the task's `studio-runtime` scratch
directory before building. Source links are dereferenced, stale files are removed,
and the original checkout is preserved. For older Sloppy packages missing the
FoundationNetworking configuration-header helper, the copy receives an Android
compatibility extension. It is omitted when the upstream implementation exists.
The copy also resolves the prompt/tokenizer bundles from the native host's
extracted `ADAENGINE_RESOURCE_ROOT`, instead of SwiftPM's build-machine paths.

## Platform boundaries

- Agent operations require keeping Studio open; Android foreground-service
  background execution is not provided.
- Dictation opens the installed Android speech recognizer. Availability and
  offline support depend on the device's recognizer and language packs.
- Files/photos use Android's document providers, copying at most eight files
  of up to 8 MB each into private cache storage. Clipboard image paste is not
  provided; use the attachment picker.
- Codex device authorization uses the external browser and returns through
  polling. Ada Cloud uses a validated state/PKCE callback and encrypted storage.
- Existing Cloud subscriptions can be refreshed after sign-in. New Pro purchases
  and purchase restoration through Google Play Billing are not implemented.
- External AdaPlayer pairing depends on Apple's Network framework and is not
  provided on Android. Use the embedded mobile Play screen.
- This produces a development-signed APK, not a Play Store AAB.

## Validation

Packaging tests: `python3 -m unittest discover -s Tools/Android/tests -v`.
Portable PNG tests: `swift test --filter PortablePNGTests` from the engine root.
The Java/D8 host and JNI adapter can be compiled separately from Swift, but those
checks do not establish Studio UI, agent, Cloud or rendered Play correctness.
Validate an installed APK on each ABI/device being shipped: project creation,
typing with an IME, saving/reopening, scene editing, Play, Back, rotation,
pause/resume, attachments and account sign-in.

### Port verification (2026-10-16)

- Built and packaged both `arm64-v8a` and `x86_64` using Swift 6.4, Android SDK 36,
  NDK r28c and the matching Android Dawn artifacts. APK signature and 16 KiB ZIP
  alignment checks passed. ARM64 was built but has not been run on a physical device.
- All 18 Android packaging/runtime-staging Python tests passed.
- The portable HTTP transport passed four isolated Swift Testing cases plus a
  real HTTP-server smoke covering exact bytes, size limits, redirects and cancellation.
- An isolated Android NativeActivity fixture exercised the production PNG encoder
  for all five pixel formats and rejected an invalid buffer. The production JNI
  and Java host passed Unicode/emoji Keystore write/read/delete, committed text
  through InputConnection into AdaUI, a native EditText prompt and document-provider
  import with byte-for-byte verification. These checks use a separate temporary
  app, with no testing controls added to Studio.
- Studio's home screen rendered through Vulkan on the Android 15 (API 35) x86_64 emulator; Back,
  activity recreation, pause/resume and portrait/landscape layouts were checked.
  Reopening immediately after rotation/Home/Back was repeated after fixing stale
  native-window leases; the shared UI reappeared in the existing process.
- Full project creation/edit/save/Play, agent requests, speech services and account
  authorization remain unverified. AdaUI's controls are not exposed in Android's
  accessibility tree, limiting coordinate-safe end-to-end automation. Soft-keyboard
  appearance and the InputConnection path were checked; typing by tapping a real
  keyboard, composition, selection and physical-keyboard behavior need device QA.

The ordinary engine test runner on this Linux host was blocked by existing
SwiftLint/file-length, box2d feature-macro and FileWatcher Sendable errors. The
isolated Android PNG fixture and HTTP tests above were used for the relevant
new behavior; they do not establish a passing full engine/editor test suite.
