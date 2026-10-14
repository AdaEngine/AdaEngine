#!/usr/bin/env python3
"""Generates small MagicaVoxel (.vox) fixtures used by the voxel import tests and demos.

Usage: script/generate_vox_fixtures.py [output_directory]
Defaults to Tests/AdaAssetsTests/Fixtures/vox.
"""
import struct
import sys
from pathlib import Path


def i32(value):
    return struct.pack("<i", value)


def string(value):
    data = value.encode("utf-8")
    return i32(len(data)) + data


def dictionary(values):
    out = i32(len(values))
    for key, value in values.items():
        out += string(key) + string(value)
    return out


def chunk(chunk_id, content=b"", children=b""):
    return chunk_id.encode("ascii") + i32(len(content)) + i32(len(children)) + content + children


def size_chunk(x, y, z):
    return chunk("SIZE", i32(x) + i32(y) + i32(z))


def xyzi_chunk(voxels):
    body = i32(len(voxels))
    for x, y, z, color in voxels:
        body += bytes([x, y, z, color])
    return chunk("XYZI", body)


def rgba_chunk(colors):
    palette = list(colors) + [(0, 0, 0, 255)] * (256 - len(colors))
    return chunk("RGBA", b"".join(bytes(color) for color in palette[:256]))


def transform_chunk(node_id, child, frames, name=None, layer=-1):
    attributes = {"_name": name} if name else {}
    body = i32(node_id) + dictionary(attributes) + i32(child) + i32(-1) + i32(layer) + i32(len(frames))
    for frame in frames:
        body += dictionary(frame)
    return chunk("nTRN", body)


def group_chunk(node_id, children):
    return chunk("nGRP", i32(node_id) + dictionary({}) + i32(len(children)) + b"".join(i32(c) for c in children))


def shape_chunk(node_id, models):
    body = i32(node_id) + dictionary({}) + i32(len(models))
    for model in models:
        body += i32(model) + dictionary({})
    return chunk("nSHP", body)


def material_chunk(index, properties):
    return chunk("MATL", i32(index) + dictionary(properties))


def write_vox(path, chunks):
    main = chunk("MAIN", b"", b"".join(chunks))
    path.write_bytes(b"VOX " + i32(150) + main)


# Palette: index n maps to colors[n - 1].
PALETTE = [
    (200, 60, 50, 255),    # 1 red
    (60, 160, 70, 255),    # 2 green
    (60, 90, 200, 255),    # 3 blue
    (230, 200, 60, 255),   # 4 yellow
    (200, 200, 205, 255),  # 5 light gray
    (90, 90, 100, 255),    # 6 dark gray
    (150, 100, 60, 255),   # 7 brown
]


def castle():
    """A 16x16x12 keep: stone floor, hollow walls with a door, corner towers and a red flag."""
    voxels = {}

    def put(x, y, z, color):
        voxels[(x, y, z)] = color

    for x in range(16):
        for y in range(16):
            put(x, y, 0, 2 if (x + y) % 5 else 7)
    for z in range(1, 7):
        for x in range(2, 14):
            for y in (2, 13):
                put(x, y, z, 5)
        for y in range(2, 14):
            for x in (2, 13):
                put(x, y, z, 5)
    for z in range(1, 4):
        for x in (7, 8):
            voxels.pop((x, 2, z), None)
    for cx, cy in ((1, 1), (12, 1), (1, 12), (12, 12)):
        for z in range(1, 10):
            for x in range(cx, cx + 3):
                for y in range(cy, cy + 3):
                    put(x, y, z, 6)
        for x in range(cx, cx + 3):
            for y in range(cy, cy + 3):
                put(x, y, 10, 3)
    for z in range(7, 12):
        put(7, 7, z, 7)
    for z in (10, 11):
        for x in (8, 9):
            put(x, 7, z, 1)
    return [
        size_chunk(16, 16, 12),
        xyzi_chunk([(x, y, z, c) for (x, y, z), c in sorted(voxels.items())]),
        rgba_chunk(PALETTE),
        material_chunk(1, {"_type": "_diffuse", "_weight": "1"}),
    ]


def box(size, color, hollow=False):
    sx, sy, sz = size
    return [(x, y, z, color) for x in range(sx) for y in range(sy) for z in range(sz)]


def robot():
    """A scene graph with three parts; the arm has two keyframes (frame 0 and 10)."""
    body = box((6, 4, 8), 3)
    head = box((4, 4, 4), 5) + [(0, 0, 2, 1), (3, 0, 2, 1)]
    arm = box((2, 2, 6), 4)
    rotation_none = {"_r": "4"}
    chunks = [
        size_chunk(6, 4, 8), xyzi_chunk(body),
        size_chunk(4, 4, 4), xyzi_chunk(head),
        size_chunk(2, 2, 6), xyzi_chunk(arm),
        transform_chunk(0, 1, [{}]),
        group_chunk(1, [2, 4, 6]),
        transform_chunk(2, 3, [{"_t": "0 0 4"}], name="body"),
        shape_chunk(3, [0]),
        transform_chunk(4, 5, [{"_t": "0 0 10"}], name="head"),
        shape_chunk(5, [1]),
        transform_chunk(
            6, 7,
            [
                {"_t": "5 0 5", "_f": "0", **rotation_none},
                {"_t": "5 0 5", "_f": "10", "_r": "17"},
            ],
            name="arm",
        ),
        shape_chunk(7, [2]),
        rgba_chunk(PALETTE),
    ]
    return chunks


def main():
    root = Path(__file__).resolve().parent.parent
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "Tests/AdaAssetsTests/Fixtures/vox"
    output.mkdir(parents=True, exist_ok=True)
    write_vox(output / "castle.vox", castle())
    write_vox(output / "robot.vox", robot())
    print(f"Wrote fixtures to {output}")


if __name__ == "__main__":
    main()
