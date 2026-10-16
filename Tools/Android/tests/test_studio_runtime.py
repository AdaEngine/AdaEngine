import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "prepare_runtime", Path(__file__).parents[3] / "Editor/Platforms/Android/prepare_runtime.py"
)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class StudioRuntimeStagingTests(unittest.TestCase):
    def packages(self, root):
        for name in ("SloppyRuntime", "SloppyComputerControl", "SwiftTiktoken"):
            package = root / "source" / name
            (package / "Sources/PluginSDK").mkdir(parents=True)
            (package / "Package.swift").write_text("// fixture", encoding="utf-8")
        source = root / "source/SloppyRuntime"
        (source / "Sources/PluginSDK/Model.swift").write_text("applyingConfigurationHeaders(to: request)", encoding="utf-8")
        return source

    def test_staging_preserves_source_and_removes_deleted_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.packages(root)
            obsolete = source / "Sources/PluginSDK/Old.swift"
            obsolete.write_text("old", encoding="utf-8")
            staged = runtime.prepare_runtime(source, root / "scratch")
            self.assertTrue((staged / "Sources/PluginSDK/Old.swift").exists())
            self.assertFalse((source / "Sources/PluginSDK/AndroidConfigurationHeaders.swift").exists())
            obsolete.unlink()
            runtime.prepare_runtime(source, root / "scratch")
            self.assertFalse((staged / "Sources/PluginSDK/Old.swift").exists())
            self.assertEqual((source / "Sources/PluginSDK/Model.swift").read_text(), "applyingConfigurationHeaders(to: request)")

    def test_upstream_helper_replaces_the_compatibility_extension(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.packages(root)
            staged = runtime.prepare_runtime(source, root / "scratch")
            shim = staged / "Sources/PluginSDK/AndroidConfigurationHeaders.swift"
            self.assertTrue(shim.exists())
            (source / "Sources/PluginSDK/Headers.swift").write_text("func applyingConfigurationHeaders(to request: URLRequest) {}", encoding="utf-8")
            runtime.prepare_runtime(source, root / "scratch")
            self.assertFalse(shim.exists())

    def test_staging_inside_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = self.packages(Path(directory))
            with self.assertRaisesRegex(ValueError, "must be separate"):
                runtime.prepare_runtime(source, source / "scratch")

    def test_resource_lookup_uses_extracted_bundles_without_rewriting_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.packages(root)
            reader = source / "Sources/SloppyRuntime/Reader.swift"
            reader.parent.mkdir()
            reader.write_text("let root = Bundle.module.resourceURL", encoding="utf-8")
            staged = runtime.prepare_runtime(source, root / "scratch")
            staged_reader = staged / "Sources/SloppyRuntime/Reader.swift"
            self.assertEqual(staged_reader.read_text(), "let root = Bundle.androidStudioModule.resourceURL")
            self.assertEqual(reader.read_text(), "let root = Bundle.module.resourceURL")
            original_time = staged_reader.stat().st_mtime_ns
            runtime.prepare_runtime(source, root / "scratch")
            self.assertEqual(staged_reader.stat().st_mtime_ns, original_time)
            adapter = staged / "Sources/SloppyRuntime/AndroidStudioResources.swift"
            self.assertIn("SloppyRuntimePortable_SloppyRuntime.", adapter.read_text())

    def test_missing_sibling_package_fails_before_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.packages(root)
            (source.parent / "SwiftTiktoken/Package.swift").unlink()
            with self.assertRaisesRegex(ValueError, "SwiftTiktoken"):
                runtime.prepare_runtime(source, root / "scratch")
