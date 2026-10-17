from pathlib import Path
import stat
import tempfile
import unittest

from prepare_swan_linux import stage


class SwanLinuxStagingTests(unittest.TestCase):
    def test_stages_readonly_checkout_and_keeps_source_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            source.mkdir()
            original = "let supportedNativePlatforms: [Platform] = [.macOS, .windows]\n"
            manifest = source / "Package.swift"
            manifest.write_text(original, encoding="utf-8")
            manifest.chmod(stat.S_IREAD)
            try:
                destination = stage(source, root / "linux-swan")
                self.assertIn(".linux", (destination / "Package.swift").read_text(encoding="utf-8"))
                self.assertEqual(manifest.read_text(encoding="utf-8"), original)
                stage(source, destination)
            finally:
                manifest.chmod(stat.S_IREAD | stat.S_IWRITE)

    def test_rejects_unrelated_destination_and_overlapping_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            source.mkdir()
            (source / "Package.swift").write_text("let supportedNativePlatforms: [Platform] = [.macOS, .windows]\n", encoding="utf-8")
            destination = root / "existing"
            destination.mkdir()
            with self.assertRaises(ValueError):
                stage(source, destination)
            with self.assertRaises(ValueError):
                stage(source, source / "nested")


if __name__ == "__main__":
    unittest.main()
