"""Render docs/phase0/route_sample.png: OSM rail network (faint), the GTFS shape (straight stop-to-stop)
and the OSM-routed track geometry for the sample trains in data/cache/phase0/route_samples.geojson."""
import json
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

rail = json.load(open("data/cache/osm/rail.json"))
nodes = rail["nodes"]
fc = json.load(open("data/cache/phase0/route_samples.geojson"))

fig, axes = plt.subplots(1, 2, figsize=(14, 9), facecolor="#0b0f14")
views = [("Stockholm C → Göteborg C (SJ 423)", "423", (11.7, 18.3, 57.5, 59.6)),
         ("Detail: Alingsås–Göteborg", "423", (11.9, 12.6, 57.65, 57.95))]
for ax, (title, train, (x0, x1, y0, y1)) in zip(axes, views):
    ax.set_facecolor("#0b0f14")
    for w in rail["ways"]:
        pts = [nodes[str(n)] for n in w[4] if str(n) in nodes]
        if not pts or not any(x0 <= p[1] <= x1 and y0 <= p[0] <= y1 for p in pts[:: max(1, len(pts) // 5)]):
            continue
        ax.plot([p[1] for p in pts], [p[0] for p in pts], color="#3a4552", lw=0.5)
    for f in fc["features"]:
        if f["properties"]["train"] != train:
            continue
        xs = [c[0] for c in f["geometry"]["coordinates"]]
        ys = [c[1] for c in f["geometry"]["coordinates"]]
        if f["properties"]["kind"] == "gtfs_shape":
            ax.plot(xs, ys, color="#ff6b6b", lw=1.2, ls="--", label=f"GTFS shape ({f['properties']['points']} points)")
            ax.scatter(xs, ys, color="#ff6b6b", s=10, zorder=5)
        else:
            ax.plot(xs, ys, color="#4cc9f0", lw=2, label=f"OSM-routed ({f['properties']['km']} km)")
    ax.set_xlim(x0, x1); ax.set_ylim(y0, y1)
    ax.set_aspect(1 / 0.53)
    ax.set_title(title, color="white")
    ax.tick_params(colors="#777")
    ax.legend(facecolor="#1a222c", labelcolor="white", loc="lower right")
fig.text(0.01, 0.01, "Rail network © OpenStreetMap contributors (ODbL). Timetable: Trafiklab GTFS Sweden 3 (CC0).", color="#888", fontsize=8)
plt.tight_layout()
plt.savefig("docs/phase0/route_sample.png", dpi=110, facecolor=fig.get_facecolor())
print("wrote docs/phase0/route_sample.png")
