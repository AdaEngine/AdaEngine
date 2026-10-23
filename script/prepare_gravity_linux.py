#!/usr/bin/env python3
"""Stage Gravity's pinned binding with C-owned strings and UTF-8 source lengths."""
import argparse
from pathlib import Path
import shutil


def stage(source, destination):
    source, destination = source.resolve(), destination.resolve()
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError("Source and destination must be separate directories")
    marker = destination / ".adaengine-linux-gravity"
    if destination.exists() and not marker.is_file():
        raise ValueError("Destination exists and is not a Linux Gravity staging directory")
    if not destination.exists():
        shutil.copytree(source, destination, ignore=shutil.ignore_patterns(".git", ".build", ".swiftpm"))
        marker.write_text(str(source) + "\n", encoding="utf-8")
    for relative in ("GravityCompiler.swift", "GravityVirtualMachine+Bridge.swift"):
        path = destination / "binding/GravitySwift" / relative
        text = path.read_text(encoding="utf-8")
        if "source.count" not in text and "source.utf8.count" not in text:
            raise ValueError("Unrecognized Gravity source-length binding: " + relative)
        path.chmod(path.stat().st_mode | 0o200)
        path.write_text(text.replace("source.count", "source.utf8.count"), encoding="utf-8")
    path = destination / "binding/GravitySwift/GSValue.swift"
    text = path.read_text(encoding="utf-8")
    start = text.find("        let mutStr = UnsafeMutablePointer<CChar>.init(mutating: string.toPointer())")
    end = text.find("        let value = gravity_value_from_object(object)", start)
    if start >= 0 and end >= start:
        end += len("        let value = gravity_value_from_object(object)")
        text = text[:start] + """        // Copy UTF-8 bytes using the VM allocator; never transfer Swift storage to C.
        let value = string.withCString { pointer in
            gravity_string_to_value(vm.vmPtr, pointer, UInt32(string.utf8.count))
        }""" + text[end:]
        path.chmod(path.stat().st_mode | 0o200)
        path.write_text(text, encoding="utf-8")
    elif "gravity_string_to_value(vm.vmPtr, pointer, UInt32(string.utf8.count))" not in text:
        raise ValueError("Unrecognized Gravity string ownership binding")
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(stage(args.source, args.destination))
