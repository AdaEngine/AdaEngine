import csv
from pathlib import Path
import tempfile
import unittest

from summarize_presentmon import summarize


class PresentMonSummaryTests(unittest.TestCase):
    def capture(self, rows):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "capture.csv"
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=[
                "ProcessID", "SwapChainAddress", "TimeInMs", "MsBetweenPresents",
                "MsBetweenDisplayChange", "MsUntilDisplayed", "MsGPUBusy",
            ])
            writer.writeheader()
            writer.writerows(rows)
        return path

    def test_windows_are_not_combined_and_boundary_interval_is_excluded(self):
        rows = []
        for swapchain in ["0x1", "0x2"]:
            for index in range(4):
                rows.append({
                    "ProcessID": "42", "SwapChainAddress": swapchain,
                    "TimeInMs": index * 1000 / 30,
                    "MsBetweenPresents": 500 if index == 0 else 1000 / 30,
                    "MsBetweenDisplayChange": 1000 / 30, "MsUntilDisplayed": "NA",
                    "MsGPUBusy": "2.5",
                })
        result = summarize(self.capture(rows))
        self.assertEqual(len(result), 2)
        for window in result:
            self.assertAlmostEqual(window["present"]["fps"], 30)
            self.assertAlmostEqual(window["elapsed_seconds"], 0.1)
            self.assertEqual(window["present"]["samples"], 3)
            self.assertEqual(window["frames_without_display_timestamp"], 4)
            self.assertNotIn("fps", window["gpu_busy"])

    def test_empty_capture_is_not_reported_as_success(self):
        with self.assertRaisesRegex(ValueError, "no presents"):
            summarize(self.capture([]))

    def test_missing_display_data_is_not_reported_as_zero_fps(self):
        rows = [{"ProcessID": "1", "SwapChainAddress": "0x1", "TimeInMs": time,
                 "MsBetweenPresents": "16.6667", "MsBetweenDisplayChange": "NA"}
                for time in [0, 16.6667, 33.3334]]
        result = summarize(self.capture(rows))[0]
        self.assertIsNone(result["display"])
        self.assertAlmostEqual(result["present"]["fps"], 60, places=3)

    def test_zero_gpu_work_is_a_valid_duration(self):
        rows = [{"ProcessID": "1", "SwapChainAddress": "0x1", "TimeInMs": index * 10,
                 "MsBetweenPresents": "10", "MsGPUBusy": busy}
                for index, busy in enumerate(["NA", "0", "2"])]
        self.assertEqual(summarize(self.capture(rows))[0]["gpu_busy"]["mean_ms"], 1)


if __name__ == "__main__":
    unittest.main()
