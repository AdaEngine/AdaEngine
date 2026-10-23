import os
from pathlib import Path
import unittest

import build_worker


@unittest.skipUnless(os.name == "posix", "The cross-build worker runs in WSL")
class BuildWorkerCacheTests(unittest.TestCase):
    def test_windows_scratch_uses_persistent_linux_cache_across_export_stages(self):
        stages = [Path("/mnt/d/Game/Exports/.ada-aot-first"), Path("/mnt/d/Game/Exports/.ada-aot-second")]
        paths = [build_worker.scratch_directory(stage, "android", "Game", "swift-6.4.0-RELEASE_android",
                                              "/mnt/d/Game/.ada/android-build") for stage in stages]
        self.assertEqual(paths[0], paths[1])
        self.assertEqual(paths[0].parent, build_worker.HOME / "builds/android")

    def test_explicit_linux_scratch_is_preserved(self):
        scratch = Path("/tmp/ada-custom-cache")
        actual = build_worker.scratch_directory(Path("/mnt/d/Game"), "web", "Game", "wasm", scratch)
        self.assertEqual(actual, scratch)

    def test_export_local_scratch_is_not_deleted_with_export_and_modes_do_not_share_cache(self):
        stage = Path("/tmp/Game/Exports/.ada-android-first")
        android = build_worker.scratch_directory(stage, "android", "Game", "sdk", stage / "build")
        web = build_worker.scratch_directory(stage, "web", "Game", "sdk", stage / "build")
        self.assertEqual(android.parent, build_worker.HOME / "builds/android")
        self.assertEqual(web.parent, build_worker.HOME / "builds/web")
        self.assertNotEqual(android, web)


if __name__ == "__main__":
    unittest.main()
