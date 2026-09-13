from pathlib import Path
import plistlib, shutil, sys
binary = Path(sys.argv[1])
app = Path(sys.argv[2])
if app.exists():
    shutil.rmtree(app)
(app / "Contents/MacOS").mkdir(parents=True, exist_ok=True)
(app / "Contents/Resources").mkdir(exist_ok=True)
shutil.copy2(binary / "StarQuest", app / "Contents/MacOS/StarQuest")
for bundle in binary.glob("*.bundle"):
    shutil.copytree(bundle, app / "Contents/Resources" / bundle.name, dirs_exist_ok=True)
(app / "Contents/Info.plist").write_bytes(plistlib.dumps({
    "CFBundleIdentifier": "org.adaengine.demo.starquest", "CFBundleName": "StarQuest",
    "CFBundleExecutable": "StarQuest", "CFBundlePackageType": "APPL",
    "NSPrincipalClass": "NSApplication", "LSMinimumSystemVersion": "15.0"
}))
