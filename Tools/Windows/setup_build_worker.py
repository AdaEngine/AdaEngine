#!/usr/bin/env python3
"""Install isolated Linux cross-build tools for Windows Studio's WSL worker."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HOME = Path.home() / ".local/share/AdaStudio/BuildTools"
SWAN_REVISION = "1eb45a22c79439b50e9cde774454450e50147149"
DAWN_REVISION = "3ab1df504f1af37a64f8d3949e77b0868e154894"


def run(command, *, env=None, cwd=None):
    print("+ " + " ".join(map(str, command)), flush=True)
    subprocess.run(list(map(str, command)), check=True, env=env, cwd=cwd)


def download(url, checksum=None):
    path = HOME / "downloads" / url.rsplit("/", 1)[-1]
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        partial = path.with_suffix(path.suffix + ".partial")
        print("Downloading " + url, flush=True)
        with urllib.request.urlopen(url, timeout=120) as response, partial.open("wb") as stream:
            shutil.copyfileobj(response, stream, 1024 * 1024)
        partial.replace(path)
    if checksum:
        digest = hashlib.file_digest(path.open("rb"), "sha256").hexdigest()
        if digest != checksum:
            raise RuntimeError(f"Checksum mismatch for {path.name}")
    return path


def extract_zip(archive, directory):
    """NDK ZIPs contain executable modes and symlinks; extractall loses both."""
    root = directory.resolve()
    root.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as stream:
        for info in stream.infolist():
            destination = root / info.filename
            if not destination.parent.resolve().is_relative_to(root):
                raise RuntimeError("Archive path escapes the tool directory")
            mode = info.external_attr >> 16
            if info.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            if stat.S_ISLNK(mode):
                target = stream.read(info).decode()
                if not (destination.parent / target).resolve().is_relative_to(root):
                    raise RuntimeError("Archive symlink escapes the tool directory")
                if destination.is_symlink() or destination.exists():
                    destination.unlink()
                destination.symlink_to(target)
            else:
                with stream.open(info) as source, destination.open("wb") as output:
                    shutil.copyfileobj(source, output)
                if mode & 0o777:
                    destination.chmod(mode & 0o777)


def swift(version):
    destination = HOME / f"swift-{version}"
    if not (destination / "usr/bin/swift").exists():
        archive = download(f"https://download.swift.org/swift-{version}-release/ubuntu2404/swift-{version}-RELEASE/swift-{version}-RELEASE-ubuntu24.04.tar.gz")
        with tarfile.open(archive) as stream:
            stream.extractall(HOME / "unpack", filter="data")
        (HOME / "unpack" / f"swift-{version}-RELEASE-ubuntu24.04").rename(destination)
    return destination / "usr/bin/swift"


def sdk(version, platform, checksum=None):
    compiler = swift(version)
    identifier = f"swift-{version}-RELEASE_{platform}"
    existing = subprocess.check_output([compiler, "sdk", "list"], text=True)
    if identifier not in existing:
        archive = download(f"https://download.swift.org/swift-{version}-release/{platform}-sdk/swift-{version}-RELEASE/{identifier}.artifactbundle.tar.gz", checksum)
        run([compiler, "sdk", "install", archive])
    return compiler


def clone(url, revision, target):
    if not (target / ".git").exists():
        run(["git", "init", target])
        run(["git", "-C", target, "remote", "add", "origin", url])
        run(["git", "-C", target, "fetch", "--depth", "1", "origin", revision])
        run(["git", "-C", target, "checkout", "--detach", "FETCH_HEAD"])
    actual = subprocess.check_output(["git", "-C", target, "rev-parse", "HEAD"], text=True).strip()
    if actual != revision:
        raise RuntimeError(f"Unexpected revision in task-owned checkout {target}")


def android():
    compiler = sdk("6.4.0", "android", "21fb555122a3d801ad943d48df7ebffdd8824de61c25c180bb792d3edaee0b43")
    ndk = HOME / "android-ndk-r28c"
    if not (ndk / ".ada-extraction-v1").is_file():
        archive = download("https://dl.google.com/android/repository/android-ndk-r28c-linux.zip")
        extract_zip(archive, HOME)
        (ndk / ".ada-extraction-v1").touch()
    sdk_root = HOME / "android-sdk"
    manager = sdk_root / "cmdline-tools/latest/bin/sdkmanager"
    if not manager.is_file():
        archive = download("https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip")
        extract_zip(archive, sdk_root / "command-download")
        manager.parent.parent.parent.mkdir(parents=True, exist_ok=True)
        (sdk_root / "command-download/cmdline-tools").rename(manager.parent.parent)
        for executable in manager.parent.iterdir():
            executable.chmod(0o755)
    # Reuse licenses already accepted in the native Windows Android SDK.
    parser_licenses = os.environ.get("ADA_WINDOWS_ANDROID_LICENSES")
    if parser_licenses:
        shutil.copytree(parser_licenses, sdk_root / "licenses", dirs_exist_ok=True)
    env = os.environ.copy()
    env.update(ANDROID_NDK_HOME=str(ndk), JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64")
    run([manager, "--sdk_root=" + str(sdk_root), "platforms;android-36", "build-tools;36.0.0", "platform-tools"], env=env)
    bundles = Path.home() / ".swiftpm/swift-sdks"
    bundle = bundles / "swift-6.4.0-RELEASE_android.artifactbundle/swift-android"
    setup = bundle / "scripts/setup-android-sdk.sh"
    if setup.is_file():
        run(["bash", setup], env=env)
    prepare_dawn(ndk)


def prepare_dawn(ndk):
    swan, dawn = HOME / "swan-android", HOME / "dawn-android"
    clone("https://github.com/adobe/swan.git", SWAN_REVISION, swan)
    clone("https://dawn.googlesource.com/dawn", DAWN_REVISION, dawn)
    artifact = swan / "Dawn/dist/android.artifactbundle"
    variants = []
    for abi, arch in [("x86_64", "x86_64"), ("arm64-v8a", "aarch64")]:
        output = artifact / abi
        library = output / "libwebgpu_dawn.so"
        if not library.exists():
            build = HOME / ("dawn-build-" + abi)
            options = ["-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_TOOLCHAIN_FILE=" + str(ndk / "build/cmake/android.toolchain.cmake"),
                       "-DANDROID_ABI=" + abi, "-DANDROID_PLATFORM=android-29", "-DDAWN_FETCH_DEPENDENCIES=ON",
                       "-DDAWN_BUILD_MONOLITHIC_LIBRARY=SHARED", "-DDAWN_ENABLE_VULKAN=ON", "-DDAWN_ENABLE_OPENGLES=ON",
                       "-DDAWN_ENABLE_DESKTOP_GL=OFF", "-DDAWN_ENABLE_D3D11=OFF", "-DDAWN_ENABLE_D3D12=OFF",
                       "-DDAWN_ENABLE_METAL=OFF", "-DDAWN_BUILD_SAMPLES=OFF", "-DDAWN_BUILD_TESTS=OFF",
                       "-DCMAKE_SHARED_LINKER_FLAGS=-llog -landroid",
                       "-DTINT_BUILD_TESTS=OFF", "-DTINT_BUILD_CMD_TOOLS=OFF"]
            run(["cmake", "-S", dawn, "-B", build, "-G", "Ninja"] + options)
            run(["cmake", "--build", build, "--target", "webgpu_dawn", "--parallel", "6"])
            candidates = list(build.rglob("libwebgpu_dawn.so"))
            if len(candidates) != 1:
                raise RuntimeError("Dawn did not produce one Android runtime library")
            output.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidates[0], library)
            shutil.copytree(dawn / "include", output / "include", dirs_exist_ok=True)
            shutil.copytree(build / "gen/include", output / "include", dirs_exist_ok=True)
        variants.append({"path": str(library.relative_to(artifact)), "supportedTriples": [f"{arch}-unknown-linux-android29"],
                         "staticLibraryMetadata": {"headerPaths": [abi + "/include"]}})
    (artifact / "info.json").write_text(json.dumps({"schemaVersion": "1.0", "artifacts": {"dawn_webgpu": {
        "type": "staticLibrary", "version": "147.0.7727.50", "variants": variants}}}, indent=2))
    # Runtime-only package: no generators or host-only demos in a cross build.
    (swan / "Package.swift").write_text('''// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "Swan", products: [.library(name: "WebGPU", targets: ["WebGPU"])], targets: [
    .binaryTarget(name: "DawnLib", path: "Dawn/dist/android.artifactbundle"),
    .target(name: "CDawn", dependencies: ["DawnLib"], cxxSettings: [.unsafeFlags(["-std=c++23"])]),
    .target(name: "Dawn", dependencies: ["CDawn", "DawnLib"]),
    .target(name: "WebGPUDawn", dependencies: ["Dawn"], path: "Sources/WebGPU/Dawn"),
    .target(name: "WebGPU", dependencies: ["WebGPUDawn"], exclude: ["Dawn", "Wasm"])
])
''')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web", action="store_true")
    parser.add_argument("--android", action="store_true")
    options = parser.parse_args()
    HOME.mkdir(parents=True, exist_ok=True)
    if options.web or not options.android:
        sdk("6.3.2", "wasm")
    if options.android or not options.web:
        android()
    print("Windows cross-build tools are ready.", flush=True)


if __name__ == "__main__":
    main()
