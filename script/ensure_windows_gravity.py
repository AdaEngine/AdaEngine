#!/usr/bin/env python3
"""Locate the checked-in AdaScript dependency used by Windows build/export helpers."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPENDENCY = ROOT / "Sources" / "gravity-lang"


def main():
    for name in ["Package.swift", "UPSTREAM.md", "binding/GravitySwift/GSValue.swift", "src/shared/gravity_aot_runtime.h"]:
        if not (DEPENDENCY / name).is_file():
            raise RuntimeError(f"Missing pinned AdaScript source: {DEPENDENCY / name}")
    print(DEPENDENCY)


if __name__ == "__main__":
    main()
