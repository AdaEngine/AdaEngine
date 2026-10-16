"""Summarize PresentMon 2.x hybrid CSV captures without combining window FPS.

Capture a warmed-up, foreground Release process, for example:
  PresentMon.exe --process_id PID --session_name AdaStudioPerf --delay 5 \
    --timed 30 --terminate_after_timed --no_console_stats --output_file editor.csv
  python script/summarize_presentmon.py editor.csv --output editor-summary.json

Frame intervals measure actual presents/display changes, not CPU update capacity.
Each swapchain is reported separately; two 30 FPS windows are never called 60 FPS.
"""

import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path
import statistics


def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (ValueError, TypeError):
        return None


def intervals(values, allow_zero=False):
    values = sorted(value for value in values
                    if value is not None and (value >= 0 if allow_zero else value > 0))
    if not values:
        return None

    def percentile(fraction):
        return values[math.ceil(len(values) * fraction) - 1]

    mean = statistics.mean(values)
    return {
        "samples": len(values),
        "fps": 1000 / mean if mean > 0 else None,
        "mean_ms": mean,
        "p50_ms": percentile(0.50),
        "p95_ms": percentile(0.95),
        "p99_ms": percentile(0.99),
        "max_ms": values[-1],
        "over_16_667_ms": sum(value > 1000 / 60 for value in values),
        "over_25_ms": sum(value > 25 for value in values),
    }


def summarize(path):
    groups = defaultdict(list)
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        required = {"ProcessID", "SwapChainAddress", "TimeInMs", "MsBetweenPresents"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError("Expected a PresentMon hybrid CSV with frame interval columns")
        for row in reader:
            groups[(row["ProcessID"], row["SwapChainAddress"])].append(row)
    if not groups:
        raise ValueError("Capture contains no presents; check process ID and window visibility")

    result = []
    for (pid, swapchain), rows in groups.items():
        times = [number(row["TimeInMs"]) for row in rows]
        # The first interval refers to a present outside the capture boundary.
        captured = rows[1:]
        result.append({
            "process_id": pid,
            "swapchain": swapchain,
            "frames": len(rows),
            "elapsed_seconds": (times[-1] - times[0]) / 1000
            if all(value is not None for value in times) else None,
            "present": intervals(number(row.get("MsBetweenPresents")) for row in captured),
            "display": intervals(number(row.get("MsBetweenDisplayChange")) for row in captured),
            "gpu_busy": intervals((number(row.get("MsGPUBusy")) for row in captured), allow_zero=True),
            "frames_without_display_timestamp": sum(
                number(row.get("MsUntilDisplayed")) is None for row in rows
            ),
            "present_modes": sorted({row.get("PresentMode", "unknown") for row in rows}),
        })
        # A duration distribution is useful for GPU work, but its reciprocal
        # is capacity rather than display FPS. Do not label it as a frame rate.
        if result[-1]["gpu_busy"]:
            del result[-1]["gpu_busy"]["fps"]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = summarize(args.capture)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    content = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(content, encoding="utf-8")
    print(content, end="")


if __name__ == "__main__":
    main()
