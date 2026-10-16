"""Stage the portable agent packages without changing the user's Sloppy checkout."""
import os
from pathlib import Path
import shutil

HEADER_COMPATIBILITY = """#if os(Android) && canImport(FoundationNetworking)
import Foundation
import FoundationNetworking

// Older portable Sloppy checkouts call this helper without defining it.
// Explicit request headers take precedence over URLSession configuration headers.
extension URLSession {
    func applyingConfigurationHeaders(to request: URLRequest) -> URLRequest {
        var request = request
        for (name, value) in configuration.httpAdditionalHeaders ?? [:] {
            guard let name = name as? String, request.value(forHTTPHeaderField: name) == nil else { continue }
            request.setValue(String(describing: value), forHTTPHeaderField: name)
        }
        return request
    }
}
#endif
"""

RESOURCE_COMPATIBILITY = """import Foundation
extension Bundle {
    static var androidStudioModule: Bundle {
        #if os(Android)
        if let root = ProcessInfo.processInfo.environment["ADAENGINE_RESOURCE_ROOT"] {
            for suffix in ["resources", "bundle"] {
                let url = URL(fileURLWithPath: root).appendingPathComponent("SloppyRuntimePortable_TARGET." + suffix)
                if let bundle = Bundle(url: url) { return bundle }
            }
        }
        preconditionFailure("Android agent resources were not packaged by studio.py")
        #else
        return .module
        #endif
    }
}
"""


def synchronize_package(source, destination):
    """Copy real package files, dereferencing the portable package's source links."""
    expected = {Path("Sources/PluginSDK/AndroidConfigurationHeaders.swift")}
    expected.update(Path("Sources") / target / "AndroidStudioResources.swift" for target in ("PluginSDK", "SloppyRuntime"))
    for item in ("Package.swift", "Sources", "Tests"):
        root = source / item
        if not root.exists():
            continue
        files = [root] if root.is_file() else (
            Path(folder) / name for folder, _, names in os.walk(root, followlinks=True) for name in names
        )
        for file in files:
            relative = file.relative_to(source)
            expected.add(relative)
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if file.suffix == ".swift" and len(relative.parts) > 2 and relative.parts[1] in ("PluginSDK", "SloppyRuntime"):
                content = file.read_bytes().replace(b"Bundle.module", b"Bundle.androidStudioModule")
                if not target.exists() or target.read_bytes() != content:
                    target.write_bytes(content)
                continue
            if not target.exists() or file.stat().st_size != target.stat().st_size or file.stat().st_mtime_ns != target.stat().st_mtime_ns:
                shutil.copy2(file, target)
    # Only remove stale files inside this explicitly task-owned staging directory.
    for file in destination.rglob("*"):
        if file.is_file() and file.relative_to(destination) not in expected:
            file.unlink()


def prepare_runtime(source, scratch):
    source = Path(source).expanduser().resolve()
    destination = Path(scratch).expanduser().resolve() / "studio-runtime"
    if source == destination or destination in source.parents or source in destination.parents:
        raise ValueError("Sloppy source and Android staging directories must be separate.")
    for package in ("SloppyRuntime", "SloppyComputerControl", "SwiftTiktoken"):
        package_source = source if package == "SloppyRuntime" else source.parent / package
        if not (package_source / "Package.swift").is_file() or not (package_source / "Sources").is_dir():
            raise ValueError(f"Missing portable agent package: {package_source}. Set SLOPPY_RUNTIME_LOCAL_PATH to Sloppy/Packages/SloppyRuntime.")
        synchronize_package(package_source, destination / package)
    plugin = destination / "SloppyRuntime/Sources/PluginSDK"
    shim = plugin / "AndroidConfigurationHeaders.swift"
    needs_helper = any("applyingConfigurationHeaders(to:" in file.read_text(encoding="utf-8") for file in plugin.glob("*.swift") if file != shim)
    has_helper = any("func applyingConfigurationHeaders(" in file.read_text(encoding="utf-8") for file in plugin.glob("*.swift") if file != shim)
    if needs_helper and not has_helper:
        if not shim.exists() or shim.read_text(encoding="utf-8") != HEADER_COMPATIBILITY:
            shim.write_text(HEADER_COMPATIBILITY, encoding="utf-8")
    elif shim.exists():
        shim.unlink()
    for target in ("PluginSDK", "SloppyRuntime"):
        directory = destination / "SloppyRuntime/Sources" / target
        if directory.is_dir():
            adapter = directory / "AndroidStudioResources.swift"
            content = RESOURCE_COMPATIBILITY.replace("TARGET", target)
            if not adapter.exists() or adapter.read_text(encoding="utf-8") != content:
                adapter.write_text(content, encoding="utf-8")
    return destination / "SloppyRuntime"
