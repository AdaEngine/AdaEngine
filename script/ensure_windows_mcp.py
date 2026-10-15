#!/usr/bin/env python3
"""Stage pinned AdaMCP as a local dependency of the Windows source build."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REVISION = "165bd5c00857a760ecea859022d023393350baad"  # Editor's AdaMCP v0.2.0


def main():
    destination = ROOT / ".build-tools" / ("adamcp-" + REVISION)
    if not destination.exists():
        # AdaMCP chooses the engine's local path when ADAENGINE_PACKAGE_PATH is set.
        # SwiftPM rejects local dependencies inside a remote revision requirement,
        # so declare this exact revision as a local package too; never edit checkouts.
        subprocess.run(["git", "clone", "--no-checkout", "https://github.com/AdaEngine/AdaMCP.git", str(destination)], check=True)
        subprocess.run(["git", "-C", str(destination), "checkout", "--detach", REVISION], check=True)
    actual = subprocess.check_output(["git", "-C", str(destination), "rev-parse", "HEAD"], text=True).strip()
    if actual != REVISION or not (destination / "Package.swift").is_file():
        raise RuntimeError("Staged AdaMCP does not match the pinned revision")
    print(destination)


if __name__ == "__main__":
    main()
