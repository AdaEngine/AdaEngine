#!/usr/bin/env python3
"""Regenerate the canonical Shader Graph AOT fixture from its AdaScript source."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--gravity", type=Path, default=Path(os.environ.get("ADAENGINE_AOT_COMPILER", root / "Sources/gravity-lang/gravity")))
args = parser.parse_args()
if not args.gravity.is_file():
    parser.error("Build the host compiler with make -C Sources/gravity-lang, or pass --gravity /path/to/gravity.")
output = root / ".build-tools/shader-graph-generated/ada_native_shader_graph.c"
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([sys.executable, str(root / "Sources/gravity-lang/tools/aot_build.py"),
                str(root / "Tests/AdaScriptAOTFixture/ShaderGraph.ada"), "--module", "ada_native_shader_graph", "--output", str(output),
                "--gravity", str(args.gravity.resolve())], check=True)
target = root / "Tests/AdaScriptAOTFixture/ShaderGraph.generated.c"
target.write_text(output.read_text().replace('#include "gravity_aot_runtime.h"', '#include <shared/gravity_aot_runtime.h>'))
print(target)
