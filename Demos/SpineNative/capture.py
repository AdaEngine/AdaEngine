"""Capture native engine pixels through AdaMCP, with no browser renderer."""
import argparse
import json
from pathlib import Path
import shutil
from time import sleep
import urllib.request


class MCP:
    def __init__(self, endpoint):
        self.endpoint = endpoint
        self.session = None
        self.sequence = 0
        self.request("initialize", {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "SpineNative capture", "version": "1.0"},
        })

    def request(self, method, params):
        self.sequence += 1
        headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        request = urllib.request.Request(self.endpoint, headers=headers, data=json.dumps({
            "jsonrpc": "2.0", "id": self.sequence, "method": method, "params": params,
        }).encode())
        with urllib.request.urlopen(request, timeout=60) as response:
            self.session = response.headers.get("Mcp-Session-Id", self.session)
            body = response.read().decode()
        if body.startswith("event:") or body.startswith("data:"):
            body = next(line[5:].strip() for line in body.splitlines() if line.startswith("data:"))
        reply = json.loads(body)
        if "error" in reply:
            raise RuntimeError(reply["error"])
        return reply["result"]

    def tool(self, name, **arguments):
        result = self.request("tools/call", {"name": name, "arguments": arguments})
        if result.get("isError"):
            raise RuntimeError(result)
        text = next(item["text"] for item in result["content"] if item["type"] == "text")
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--endpoint", default="http://127.0.0.1:2511/mcp")
    parser.add_argument("--frames", type=int, default=0, help="Also capture this many walk frames at 20 fps.")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    client = MCP(args.endpoint)
    report = {"renderGraph": client.tool("render_graph.get"), "captures": []}
    cameras = [camera for camera in report["renderGraph"]["cameras"] if camera["isActive"]]
    if len(cameras) != 1:
        raise RuntimeError("This demo expects exactly one active render camera.")
    camera_id = cameras[0]["entityId"]
    client.tool("runtime.pause", reason="Repeatable native Spine capture")
    poses = [("walk", 0.3), ("run", 0.2), ("jump", 0.35)]
    poses += [("walk", index / 20) for index in range(args.frames)]
    try:
        for index, (animation, time) in enumerate(poses):
            client.tool("spine.pose", animation=animation, time=time, playing=False)
            # Transform propagation and camera preparation run in successive phases.
            client.tool("runtime.step_frame", frames=2)
            capture = client.tool("render.capture_screenshot", cameraEntityId=camera_id)
            if capture["width"] <= 1 or capture["height"] <= 1:
                raise RuntimeError(f"Empty native capture: {capture}")
            name = f"{animation}.png" if index < 3 else f"frame-{index - 3:03d}.png"
            shutil.copy2(capture["path"], args.output / name)
            report["captures"].append(dict(capture, animation=animation, time=time, savedAs=name))
            print(f"{name}: {capture['width']}x{capture['height']}", flush=True)
            sleep(0.15)
    finally:
        (args.output / "capture-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        client.tool("spine.pose", animation="walk", time=0, playing=True)
        client.tool("runtime.resume")


if __name__ == "__main__":
    main()
