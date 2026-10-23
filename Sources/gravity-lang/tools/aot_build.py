#!/usr/bin/env python3
"""Build a Gravity AOT library using the host compiler and target SDK."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, nargs="+", help="Ordered sources compiled as one module")
    parser.add_argument("--module", required=True)
    parser.add_argument("--output", required=True, type=Path, help="Output archive (.a), standalone WASM (.wasm), or generated C (.c)")
    parser.add_argument("--gravity", type=Path, default=root / "gravity", help="Host Gravity compiler")
    parser.add_argument("--cc", default=os.environ.get("CC", "clang"))
    parser.add_argument("--ar", default=os.environ.get("AR", "llvm-ar" if shutil.which("llvm-ar") else "ar"))
    parser.add_argument("--target", help="Clang target triple")
    parser.add_argument("--sysroot", type=Path, help="Target SDK/sysroot")
    parser.add_argument("--cflag", action="append", default=[], help="Additional compiler flag; use --cflag=-flag")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", args.module):
        parser.error("module must be an ASCII identifier starting with a letter")
    if args.module in ["gravity_aot_runtime", "gravity_aot_objects", "gravity_aot_tasks"]:
        parser.error("module name conflicts with the standalone runtime header")
    sources = [path.resolve(strict=True) for path in args.source]
    output = args.output.resolve()
    if output in sources or output.suffix not in [".a", ".wasm", ".c"]:
        parser.error("output must be .a, .wasm or .c and different from the sources")
    if output.suffix == ".c" and output.name != f"{args.module}.c":
        parser.error("C output name must match the module name")
    output.parent.mkdir(parents=True, exist_ok=True)
    # No published artifacts change until all compiler/linker steps succeed.
    with tempfile.TemporaryDirectory(prefix=".gravity-aot-", dir=output.parent) as staging:
        stage = Path(staging)
        c_file = stage / f"{args.module}.c"
        header = stage / f"{args.module}.h"
        runtime = stage / "gravity_aot_runtime.h"
        obj = stage / f"{args.module}.o"
        archive = stage / output.name
        objects = stage / "gravity_aot_objects.h"
        shutil.copyfile(root / "src/shared/gravity_aot_runtime.h", runtime)
        shutil.copyfile(root / "src/shared/gravity_aot_objects.h", objects)
        tasks = stage / "gravity_aot_tasks.h"
        shutil.copyfile(root / "src/shared/gravity_aot_tasks.h", tasks)
        source = sources[0]
        source_map = []
        if len(sources) > 1:
            source = stage / "module.ada"
            combined = ""
            for path in sources:
                content = path.read_text(encoding="utf-8") + "\n"
                source_map.append({"path": str(path), "firstLine": combined.count("\n") + 1,
                                   "lineCount": content.count("\n")})
                combined += content
            source.write_text(combined, encoding="utf-8")
        else:
            source_map = [{"path": str(source), "firstLine": 1,
                           "lineCount": source.read_text(encoding="utf-8").count("\n") + 1}]
        manifest = stage / f"{args.module}.sources.json"
        manifest.write_text(json.dumps(source_map, indent=2) + "\n", encoding="utf-8")
        subprocess.run([str(args.gravity.resolve()), "--emit-c", str(source), "--module", args.module,
                        "-o", str(c_file)], check=True)
        compile_args = [args.cc, "-std=c11", "-O2", "-fPIC", "-Wall", "-Wextra", "-Werror", "-I", str(stage)]
        if args.target or output.suffix == ".wasm":
            compile_args += ["--target=" + (args.target or "wasm32-unknown-unknown")]
        if args.sysroot:
            compile_args += ["--sysroot=" + str(args.sysroot.resolve(strict=True))]
        if output.suffix == ".wasm":
            allowed = stage / "math-imports.txt"
            allowed.write_text("remainder\n")
            subprocess.run(compile_args + args.cflag + ["-nostdlib", "-fno-builtin", str(c_file),
                           "-Wl,--no-entry", f"-Wl,--export={args.module}_get_module",
                           "-Wl,--export-memory", "-Wl,--export-table",
                           "-Wl,--allow-undefined-file=" + str(allowed), "-o", str(archive)], check=True)
        elif output.suffix == ".a":
            subprocess.run(compile_args + args.cflag + ["-c", str(c_file), "-o", str(obj)], check=True)
            subprocess.run([args.ar, "rcs", str(archive), str(obj)], check=True)
        header.write_text(f'''/* Generated Gravity AOT module accessor. */
#ifndef GRAVITY_AOT_MODULE_{args.module.upper()}_H
#define GRAVITY_AOT_MODULE_{args.module.upper()}_H
#include "gravity_aot_runtime.h"
#ifdef __cplusplus
extern "C" {{
#endif
const gravity_aot_module *{args.module}_get_module(void);
#ifdef __cplusplus
}}
#endif
#endif
''')
        artifacts = [c_file, header, runtime, objects, tasks, manifest]
        if output.suffix != ".c":
            artifacts.append(archive)
        for artifact in artifacts:
            os.replace(artifact, output.parent / artifact.name)
    print(output)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"AOT build failed: {error}", file=sys.stderr)
        sys.exit(1)
