"""Write the LiDAR meshes of a station walk (the walk tool's LiDAR mode) as PLY files, one per snapshot.

A walk file (`data/walklogs/<id>.walk` on the server, or exported from the phone) is JSON compressed with raw DEFLATE.
Its `meshes` hold Float32 vertices and UInt32 triangles (base64) in the AR session's frame: metres, x east, y up,
z south, from where AR mode started (WalkLog.ARMesh). The walk's `ar` poses are in the same frame, so its GPS fixes and
marks place the mesh on the station map. Each triangle's ARKit class (wall, floor, ceiling, door, …) is kept as a face
property and as a colour, so floors and walls can be told apart in any viewer (MeshLab, Blender, CloudCompare).

Usage: python3 scripts/stations/walk_mesh.py <walk file or .json> [out_dir]
"""
import base64
import json
import os
import struct
import sys
import zlib

CLASSES = ["none", "wall", "floor", "ceiling", "table", "seat", "window", "door"]
COLOURS = [(160, 160, 160), (200, 120, 80), (80, 160, 90), (120, 140, 200), (190, 170, 90), (170, 100, 170), (90, 190, 200), (220, 80, 80)]


def load(path):
    raw = open(path, "rb").read()
    try:
        return json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return json.loads(zlib.decompress(raw, -15))


def main():
    path = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(path))
    walk = load(path)
    meshes = walk.get("meshes") or []
    if not meshes:
        raise SystemExit(f"{walk.get('title')}: no LiDAR mesh in this walk")
    for n, m in enumerate(meshes):
        v = base64.b64decode(m["vertices"])
        f = base64.b64decode(m["faces"])
        c = base64.b64decode(m["classes"]) if m.get("classes") else bytes(m["faceCount"])
        name = os.path.join(out, f"{walk['id']}_mesh{n + 1}.ply")
        with open(name, "wb") as ply:
            ply.write((
                "ply\nformat binary_little_endian 1.0\n"
                f"comment Clack walk '{walk.get('title')}', snapshot at {m['t']}; metres, x east, y up, z south (ARKit gravityAndHeading)\n"
                f"element vertex {m['vertexCount']}\nproperty float x\nproperty float y\nproperty float z\n"
                f"element face {m['faceCount']}\nproperty list uchar uint vertex_indices\nproperty uchar class\n"
                "property uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"
            ).encode())
            ply.write(v)
            for i in range(m["faceCount"]):
                cls = c[i] if i < len(c) else 0
                ply.write(struct.pack("<B3I", 3, *struct.unpack_from("<3I", f, i * 12)))
                ply.write(struct.pack("<4B", cls, *COLOURS[cls if cls < len(COLOURS) else 0]))
        counts = {}
        for b in c:
            counts[CLASSES[b] if b < len(CLASSES) else str(b)] = counts.get(CLASSES[b] if b < len(CLASSES) else str(b), 0) + 1
        print(f"{name}: {m['vertexCount']} vertices, {m['faceCount']} triangles; {counts}")


if __name__ == "__main__":
    main()
