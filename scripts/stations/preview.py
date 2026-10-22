"""Render a station map (data/stations/<id>.json) to a PNG, one panel per level, on a metre grid, to check a draft
against a station's own plan and read off coordinates for the edits file.

Usage: python3 scripts/stations/preview.py 740000120 [--out preview.png] [--level L0] [--labels]
A one-off data tool, like draft_from_osm.py. (pip install matplotlib)
"""
import argparse
import json
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EDGE_COLOURS = {"walk": "#7a7a7a", "stairs": "#e07b00", "escalator": "#8a2be2", "lift": "#d00000"}
POI_COLOURS = {"cafe": "#b5651d", "restaurant": "#c0392b", "kiosk": "#2e86c1", "shop": "#27ae60", "toilet": "#555", "ticket": "#f1c40f"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("station_id")
    ap.add_argument("--out")
    ap.add_argument("--level", action="append", help="only these levels (repeatable)")
    ap.add_argument("--labels", action="store_true", help="label nodes with their ids")
    ap.add_argument("--box", type=float, nargs=4, metavar=("X0", "X1", "Y0", "Y1"), help="only this part (metres)")
    args = ap.parse_args()
    m = json.load(open(os.path.join(ROOT, f"data/stations/{args.station_id}.json")))
    levels = [l for l in sorted(m["levels"], key=lambda l: -l["order"]) if not args.level or l["id"] in args.level]
    nodes = {n["id"]: n for n in m["nodes"]}
    xs = [n["x"] for n in m["nodes"]] + [p[0] for s in m["shapes"] for p in s["points"]]
    ys = [n["y"] for n in m["nodes"]] + [p[1] for s in m["shapes"] for p in s["points"]]
    pad = 15
    box = tuple(args.box) if args.box else (min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad)
    scale = 25 if not args.box else 12
    w = (box[1] - box[0]) / scale
    h = (box[3] - box[2]) / scale
    fig, axes = plt.subplots(1, len(levels), figsize=(max(6, w) * len(levels), max(6, h)), squeeze=False)
    for ax, lv in zip(axes[0], levels):
        L = lv["id"]
        ax.set_title(f"{m['name']} · {L} {lv['name']}")
        for s in m["shapes"]:
            if s["kind"] == "track":
                ax.plot([p[0] for p in s["points"]], [p[1] for p in s["points"]], color="#bbb", lw=0.8, zorder=1)
            elif s["level"] == L:
                fc = {"building": "#f0f0f0", "hall": "#e8eef5", "room": "#eee", "shop": "#dfe9df"}.get(s["kind"], "#eee")
                ax.add_patch(Polygon(s["points"], closed=True, fc=fc, ec="#999", lw=0.6, zorder=0))
        for p in m["platforms"]:
            if p["level"] != L:
                continue
            for g in p["geometry"]:
                ax.add_patch(Polygon(g, closed=True, fc="#fde9a8", ec="#c9a227", lw=0.6, zorder=2))
            mid = nodes[p["node"]]
            ax.text(mid["x"], mid["y"], p["ref"], fontsize=9, weight="bold", ha="center", va="center", zorder=6, clip_on=True)
        for e in m["edges"]:
            a, b = nodes[e["from"]], nodes[e["to"]]
            if a["level"] != L and b["level"] != L:
                continue
            g = e.get("geometry") or [[a["x"], a["y"]], [b["x"], b["y"]]]
            ls = "--" if e.get("source") == "manual" else "-"
            ax.plot([q[0] for q in g], [q[1] for q in g], color=EDGE_COLOURS[e["kind"]], lw=1.6 if e["kind"] != "walk" else 0.9, ls=ls, zorder=3)
        for n in m["nodes"]:
            if n["level"] != L:
                continue
            if n["type"] == "entrance":
                ax.plot(n["x"], n["y"], marker="s", color="#1a7f37", ms=6, zorder=5)
            elif n["type"] in ("stairs", "escalator", "lift"):
                ax.plot(n["x"], n["y"], marker="o", color=EDGE_COLOURS[n["type"]], ms=3, zorder=5)
            if args.labels:
                ax.text(n["x"], n["y"], n["id"], fontsize=5, color="#333", zorder=7, clip_on=True)
        for p in m["pois"]:
            if p["level"] != L:
                continue
            c = POI_COLOURS.get(p["category"], "#666")
            if p.get("outline"):
                ax.add_patch(Polygon(p["outline"], closed=True, fc=c, alpha=0.35, ec=c, lw=0.8, zorder=4))
            ax.plot(p["x"], p["y"], marker="v", color=c, ms=5, zorder=6)
            ax.text(p["x"] + 1, p["y"] - 1, (p["name"] or p["category"])[:18], fontsize=6, color=c, zorder=7, clip_on=True)
        ax.set_xlim(box[0], box[1])
        ax.set_ylim(box[3], box[2])  # y points south
        ax.set_aspect("equal")
        ax.grid(True, lw=0.3, color="#ddd")
        step = 20 if not args.box else 10
        ax.set_xticks(range(int(box[0] // step * step), int(box[1]) + 1, step))
        ax.set_yticks(range(int(box[2] // step * step), int(box[3]) + 1, step))
        ax.tick_params(labelsize=6)
    out = args.out or os.path.join(ROOT, f"data/cache/stations/{args.station_id}-preview.png")
    fig.tight_layout()
    fig.savefig(out, dpi=90)
    print(out)


if __name__ == "__main__":
    main()
