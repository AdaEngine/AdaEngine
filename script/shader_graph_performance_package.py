#!/usr/bin/env python3
"""Stage the same ordinary-material frame benchmarks against either engine checkout."""
import argparse
import json
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("destination", type=Path)
parser.add_argument("--engine", type=Path, default=root)
args = parser.parse_args()
destination = args.destination.resolve()
tests = destination / "Tests/PerformanceTests"
tests.mkdir(parents=True, exist_ok=True)
for name in ["GoldenFrameSupport", "Render3DDebugViewTests", "Render3DPerformanceBenchmarkTests", "NoGraphPerformanceTests"]:
    shutil.copy2(root / "Tests/AdaEngineTests" / (name + ".swift"), tests / (name + ".swift"))
modules = ["AdaApp", "AdaCorePipelines", "AdaECS", "AdaRender", "AdaScene", "AdaSprite", "AdaTransform", "AdaUtils", "Math"]
dependencies = ",\n".join('.product(name: ' + json.dumps(name) + ', package: "AdaEngine")' for name in modules)
(destination / "Package.swift").write_text('''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "ShaderGraphPerformance", platforms: [.macOS(.v15)], dependencies: [
    .package(name: "AdaEngine", path: ''' + json.dumps(str(args.engine.resolve())) + ''')
], targets: [.testTarget(name: "PerformanceTests", dependencies: [
''' + dependencies + '''
])])
''', encoding="utf-8")
print(destination)
