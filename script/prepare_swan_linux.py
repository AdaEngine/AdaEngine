#!/usr/bin/env python3
"""Stage a local Swan copy with its existing Dawn backend enabled on Linux.

The upstream artifact index includes Linux Dawn binaries, but Swan 0.0.8's
WebGPU target does not declare its WebGPUDawn dependency on that platform.
Keep the original checkout intact and pass the printed path through
ADAENGINE_SWAN_PACKAGE_PATH when building AdaEngine.
"""
import argparse
from pathlib import Path
import shutil
import stat


def stage(source: Path, destination: Path) -> Path:
    source = source.resolve()
    destination = destination.resolve()
    if destination == source or destination.is_relative_to(source) or source.is_relative_to(destination):
        raise ValueError("Source and destination must be separate directories")
    manifest = (source / "Package.swift").read_text(encoding="utf-8")
    old = "let supportedNativePlatforms: [Platform] = [.macOS, .windows]"
    new = "let supportedNativePlatforms: [Platform] = [.macOS, .windows, .linux]"
    if old not in manifest and new not in manifest:
        raise ValueError("Unrecognized Swan manifest; inspect Linux support before applying this compatibility adjustment")
    marker = destination / ".adaengine-linux-swan"
    if destination.exists() and not marker.is_file():
        raise ValueError("Destination exists and is not an AdaEngine Swan staging directory")
    destination.mkdir(parents=True, exist_ok=True)
    marker.write_text(str(source) + "\n", encoding="utf-8")

    def copy_writable(src, dst):
        target = Path(dst)
        if target.exists():
            target.chmod(target.stat().st_mode | stat.S_IWUSR)
        shutil.copy2(src, dst)
        target.chmod(target.stat().st_mode | stat.S_IWUSR)
        return dst

    shutil.copytree(source, destination, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(".git", ".build", ".swiftpm", "Package.resolved"), copy_function=copy_writable)
    (destination / "Package.swift").write_text(manifest.replace(old, new), encoding="utf-8")
    marker.write_text(str(source) + "\n", encoding="utf-8")
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(stage(args.source, args.destination))
