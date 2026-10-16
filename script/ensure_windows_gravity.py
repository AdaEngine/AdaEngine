#!/usr/bin/env python3
"""Prepare a pinned Windows-compatible Gravity dependency outside shared .build."""
import hashlib
from pathlib import Path
import shutil
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REVISION = "26f80cc250d478b16dbbd21a3a517a669d13f616"
DESTINATION = ROOT / ".build-tools" / "gravity-windows"
PATCH_VERSION = "native-string-copy-v1"
ORIGINAL = """        let mutStr = UnsafeMutablePointer<CChar>.init(mutating: string.toPointer())
\x20\x20\x20\x20\x20\x20\x20\x20
        let object = gravity_string_new(
            vm.vmPtr,
            mutStr,
            UInt32(string.count),
            UInt32(string.count)
        )
        let value = gravity_value_from_object(object)"""
REPLACEMENT = """        // The C VM frees strings with its own allocator. Swift-allocated
        // storage cannot be handed to it on Windows; also count UTF-8 bytes.
        let value = string.withCString { pointer in
            gravity_string_to_value(vm.vmPtr, pointer, UInt32(string.utf8.count))
        }"""


def run(*arguments):
    return subprocess.check_output(arguments, text=True, stderr=sys.stderr).strip()


def main():
    source = ROOT / "Editor" / ".build" / "checkouts" / "gravity-lang"
    marker = DESTINATION / ".ada-windows-patch"
    binding = DESTINATION / "binding" / "GravitySwift" / "GSValue.swift"
    if not marker.exists():
        if not DESTINATION.exists():
            if source.exists() and run("git", "-C", str(source), "rev-parse", "HEAD") == REVISION:
                shutil.copytree(source, DESTINATION, copy_function=shutil.copyfile,
                                ignore=shutil.ignore_patterns(".git", ".build"))
            else:
                run("git", "clone", "--no-checkout", "https://github.com/AdaEngine/gravity-lang.git", str(DESTINATION))
                run("git", "-C", str(DESTINATION), "checkout", "--detach", REVISION)
        text = binding.read_text(encoding="utf-8")
        if text.count(ORIGINAL) != 1:
            raise RuntimeError("Pinned Gravity binding does not match the expected string ownership implementation.")
        binding.chmod(binding.stat().st_mode | stat.S_IWRITE)
        binding.write_text(text.replace(ORIGINAL, REPLACEMENT), encoding="utf-8")
        digest = hashlib.sha256(binding.read_bytes()).hexdigest()
        marker.write_text(f"{REVISION}\n{PATCH_VERSION}\n{digest}\n", encoding="utf-8")
    expected = marker.read_text(encoding="utf-8").splitlines()
    actual = [REVISION, PATCH_VERSION, hashlib.sha256(binding.read_bytes()).hexdigest()]
    if expected != actual:
        raise RuntimeError("Windows Gravity dependency changed after preparation; inspect the local copy.")
    print(DESTINATION)


if __name__ == "__main__":
    main()
