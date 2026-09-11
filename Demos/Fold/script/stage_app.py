from pathlib import Path
import plistlib, shutil, sys
binary = Path(sys.argv[1])
app = Path(sys.argv[2])
(app / "Contents/MacOS").mkdir(parents=True, exist_ok=True)
(app / "Contents/Resources").mkdir(exist_ok=True)
shutil.copy2(binary / "Fold", app / "Contents/MacOS/Fold")
for bundle in binary.glob("*.bundle"):
    shutil.copytree(bundle, app / "Contents/Resources" / bundle.name, dirs_exist_ok=True)
(app / "Contents/Info.plist").write_bytes(plistlib.dumps({
    "CFBundleIdentifier": "org.adaengine.demo.fold", "CFBundleName": "Fold",
    "CFBundleExecutable": "Fold", "CFBundlePackageType": "APPL",
    "NSPrincipalClass": "NSApplication", "LSMinimumSystemVersion": "15.0"
}))
