#!/usr/bin/env python3
"""Build or run Ada Studio Mobile using the engine's Android toolchain."""
import importlib.util
import os
from pathlib import Path
import sys
from prepare_runtime import prepare_runtime

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("ada_android", ROOT / "Tools/Android/android.py")
android = importlib.util.module_from_spec(spec)
spec.loader.exec_module(android)


def main():
    parser = android.parser()
    parser.set_defaults(
        package=str(ROOT / "Editor"), product="AdaStudioMobile",
        application_id="org.adaengine.studio", label="Ada Studio",
        activity="org.adaengine.studio.StudioActivity",
        java_source=[str(Path(__file__).with_name("StudioActivity.java"))],
        callback_url=["adaeditor://cloud/callback"],
        scratch=str(ROOT / ".build-android-studio"),
        output=str(ROOT / ".build-android-studio/apk"),
    )
    args = parser.parse_args()
    os.environ["ADAEDITOR_ANDROID"] = "1"
    try:
        if args.command == "build" or (args.command == "run" and not args.apk):
            source = os.environ.get("SLOPPY_RUNTIME_LOCAL_PATH", str(ROOT.parent / "Sloppy/Packages/SloppyRuntime"))
            os.environ["SLOPPY_RUNTIME_LOCAL_PATH"] = str(prepare_runtime(source, args.scratch))
        if args.command == "build": android.build(args)
        elif args.command == "run": android.launch(args)
        elif args.command == "devices": print(android.run([android.sdk_path(args)/"platform-tools/adb", "devices", "-l"], capture=True))
        else:
            # Delegate doctor with the same defaults and explicit environment.
            original = android.parser
            android.parser = lambda: parser
            try: return android.main()
            finally: android.parser = original
    except (android.AndroidError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__": sys.exit(main())
