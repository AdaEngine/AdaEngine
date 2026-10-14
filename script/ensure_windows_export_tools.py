#!/usr/bin/env python3
"""Prepare the pinned AdaScript CLI in task-owned Windows build directories."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
dependency = Path(subprocess.check_output([sys.executable, str(root / "script/ensure_windows_gravity.py")], text=True).strip())
build = root / ".build-tools/gravity-cli"
subprocess.run(["cmake", "-S", str(dependency), "-B", str(build), "-G", "Visual Studio 17 2022", "-A", "x64",
                "-DBUILD_SHARED_LIBS=OFF", "-DWINDOWS_LOCAL_INSTALL=OFF"], check=True)
subprocess.run(["cmake", "--build", str(build), "--config", "Release", "--target", "gravity"], check=True)
shutil.copy2(build / "bin/Release/gravity.exe", dependency / "gravity.exe")
print(dependency / "gravity.exe")
