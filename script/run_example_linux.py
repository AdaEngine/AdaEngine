#!/usr/bin/env python3
"""Build a private Linux copy of a Swift AdaExamples sample with this engine."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path, help="AdaExamples sample folder containing Package.swift")
    parser.add_argument("--cache", type=Path, default=Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "adaengine/examples-linux")
    parser.add_argument("--product", required=True)
    parser.add_argument("--build-only", action="store_true")
    args = parser.parse_args()
    source = args.project.resolve()
    # Pin the exact dependency declaration before copying. Never rewrite user projects in place.
    manifest = (source / "Package.swift").read_text(encoding="utf-8")
    pattern = r'\.package\(\s*url:\s*"https://github\.com/AdaEngine/AdaEngine(?:\.git)?",\s*revision:\s*"[0-9a-f]{40}"\s*\)'
    manifest, count = re.subn(pattern, lambda _: ".package(path: " + json.dumps(str(ROOT)) + ")", manifest)
    if count != 1:
        parser.error("Expected one pinned AdaEngine dependency in the sample manifest")
    cache = args.cache.resolve()
    project = cache / source.name
    marker = project / ".adaengine-linux-example"
    if project.exists():
        if not marker.is_file() or marker.read_text(encoding="utf-8").strip() != str(source):
            parser.error("Cache folder already exists and is not this sample's Linux copy")
    else:
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(".git", ".build", ".swiftpm"))
        marker.write_text(str(source) + "\n", encoding="utf-8")
        (project / "Package.swift").write_text(manifest, encoding="utf-8")
    # The catalog's pinned Fold predates the engine's editor-independent reflection API.
    # Migrate only the private working copy; the downloaded example stays untouched.
    for file in (project / "Sources").rglob("*.swift"):
        text = file.read_text(encoding="utf-8")
        if "EditorComponentFieldDescriptor" in text or "EditorComponentReflection" in text:
            text = text.replace("EditorComponentFieldDescriptor", "ReflectedComponentField")
            text = text.replace("EditorComponentReflection", "ComponentReflection").replace("isEditable:", "isWritable:")
            file.write_text(text, encoding="utf-8")
    scratch = cache / "build"
    subprocess.run(["swift", "build", "--package-path", str(project), "--scratch-path", str(scratch),
                    "--product", args.product, "--jobs", os.environ.get("ADAENGINE_SWIFT_JOBS", "4")], check=True)
    if not args.build_only:
        binary = subprocess.check_output(["swift", "build", "--package-path", str(project), "--scratch-path", str(scratch), "--show-bin-path"], text=True).strip()
        subprocess.run([str(Path(binary) / args.product)], cwd=project, check=True)


if __name__ == "__main__":
    main()
