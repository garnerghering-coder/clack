"""Write a viewable PNG of a station's ground GeoTIFF (float32 heights, as in data/stations/research/<id>/).

A float GeoTIFF shows up blank (all white) in most viewers and chat previews: its values are metres (88–97), not
0–255 grey. This scales the heights between their own minimum and maximum to 8-bit grey (low dark, high light) and
writes `<name>_preview.png` next to the file, with the range in the PNG's text chunk.

Usage: python3 scripts/stations/terrain_preview.py data/stations/research/740000090/jonkoping_c_ground_1m.tif
Plain Python (struct + zlib); reads uncompressed or deflate strips or tiles of float32, no predictor or predictor 3.
"""
import math
import struct
import sys
import zlib


def read_tiff(path, with_tags=False):
    b = open(path, "rb").read()
    bo = "<" if b[:2] == b"II" else ">"
    off = struct.unpack(bo + "I", b[4:8])[0]
    n = struct.unpack(bo + "H", b[off:off + 2])[0]
    tags = {}
    for i in range(n):
        tag, ty, count, val = struct.unpack(bo + "HHI4s", b[off + 2 + 12 * i:off + 14 + 12 * i])
        size = {3: 2, 4: 4, 12: 8, 11: 4}.get(ty, 1)
        raw = val if size * count <= 4 else b[struct.unpack(bo + "I", val)[0]:][:size * count]
        fmt = {3: "H", 4: "I", 12: "d", 11: "f"}.get(ty)
        tags[tag] = list(struct.unpack(bo + fmt * count, raw[:size * count])) if fmt else raw[:count]
    w, h = tags[256][0], tags[257][0]
    if tags.get(258, [32])[0] != 32 or tags.get(339, [3])[0] != 3:
        raise SystemExit("expected float32 samples")
    comp, pred = tags.get(259, [1])[0], tags.get(317, [1])[0]
    tiled = 322 in tags
    tw, th = (tags[322][0], tags[323][0]) if tiled else (w, tags.get(278, [h])[0])
    offs, counts = (tags[324], tags[325]) if tiled else (tags[273], tags[279])
    nodata = float(tags[42113].decode().strip("\x00")) if 42113 in tags else None
    grid = [[math.nan] * w for _ in range(h)]
    across = math.ceil(w / tw)
    for k, (o, c) in enumerate(zip(offs, counts)):
        data = b[o:o + c]
        if comp in (8, 32946):
            data = zlib.decompress(data)
        rows = len(data) // (tw * 4)
        for r in range(rows):
            row = bytearray(data[r * tw * 4:(r + 1) * tw * 4])
            if pred == 3:
                for j in range(1, len(row)):
                    row[j] = (row[j] + row[j - 1]) & 255
                row = bytes(row[b2 * tw + x] for x in range(tw) for b2 in range(4))
                vals = struct.unpack(">" + "f" * tw, row)
            else:
                vals = struct.unpack(bo + "f" * tw, bytes(row))
            y = (k // across) * th + r if tiled else k * th + r
            x0 = (k % across) * tw if tiled else 0
            if y >= h:
                continue
            for x, v in enumerate(vals):
                if x0 + x < w and v != nodata:
                    grid[y][x0 + x] = v
    return (w, h, grid, tags) if with_tags else (w, h, grid)


def write_png(path, w, h, grey, text):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(row) for row in grey)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
    png += chunk(b"tEXt", b"Comment\x00" + text.encode("latin-1", "replace"))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    path = sys.argv[1]
    w, h, grid = read_tiff(path)
    vals = [v for row in grid for v in row if not math.isnan(v)]
    lo, hi = min(vals), max(vals)
    span = max(hi - lo, 1e-6)
    grey = [[0 if math.isnan(v) else round(20 + 235 * (v - lo) / span) for v in row] for row in grid]
    out = path.rsplit(".", 1)[0] + "_preview.png"
    write_png(out, w, h, grey, f"heights {lo:.2f}-{hi:.2f} m, dark low, light high; scaled preview, not data")
    print(f"{out}: {w}x{h}, {lo:.2f}-{hi:.2f} m")


if __name__ == "__main__":
    main()
