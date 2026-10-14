#!/usr/bin/env python3
"""Compile the committed Studio icon into a Windows PE resource."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
compiler = shutil.which("llvm-rc") or shutil.which("rc")
if not compiler:
    raise RuntimeError("Windows icon resource compiler is missing. Install the Swift/Windows SDK tools.")
directory = root / "Editor/Platforms/Windows"
output = root / ".build-tools/AdaStudio.res"
output.parent.mkdir(parents=True, exist_ok=True)
if not output.exists() or output.stat().st_mtime < max((directory / name).stat().st_mtime for name in ("AdaStudio.rc", "AdaStudio.ico")):
    subprocess.run([compiler, "/fo", str(output), "AdaStudio.rc"], cwd=directory, check=True)
print(output)
