"""Danish station folders before the laser: platform register GeoJSON + README (3D pending). station_facts.json is added by facts.py.

python3 dk_register_only.py <out research dir>
"""
import json, sys, os, re
OUT = sys.argv[1]
REGD = os.environ.get('DK_REGISTER', 'data/stations/research/_sources/DK/dk_register')
ST = json.load(open(os.environ.get('DK_STATIONS', 'data/stations/research/_sources/DK/dk_stations.json')))
for s in ST:
    R = json.load(open(f"{REGD}/{s['safe']}.json"))
    slug = re.sub(r'[^a-z0-9]+', '_', s['name'].lower().replace('ø', 'o').replace('æ', 'ae').replace('å', 'a')).strip('_')
    d = f"{OUT}/{s['safe']}"; os.makedirs(d, exist_ok=True)
    feats = []
    for p in R['plat']:
        v = [float(x) for x in p['Points'].split()]
        coords = [[v[i + 1], v[i]] for i in range(0, len(v) - 1, 2)]
        feats.append({'type': 'Feature', 'geometry': {'type': 'LineString', 'coordinates': coords}, 'properties': {
            'bis_object': p['BisObjektNr'], 'track': p['x_track'], 'perron': p['x_perron'], 'perron_tracks': p['x_perron_tracks'], 'tib': p['x_tib'],
            'height_class': p['Höjd'] + ' cm', 'height_m': int(p['Höjd']) / 100, 'length_m': p['Längd_m'], 'width_m': p['Bredd_m'],
            'width_note': p['x_width_note'], 'geometry_how': p['x_geometry'], 'platform_surface_m': None, 'track_bed_m': None,
            '_source': p['_source']}})
    json.dump({'type': 'FeatureCollection', 'features': feats}, open(f'{d}/{slug}_platform_banedanmark.geojson', 'w'), ensure_ascii=False, indent=1)
    rd = f"""# {s['name']} (`{s['clack_id']}`): platform register and station facts (3D pending)

Pass of 2026-10-30 following `STATION_3D_RESEARCH_BRIEF_DK_FI.md`. **The 3D files are not here yet**: Danmarks Højdemodel's
point cloud needs a Dataforsyningen token (the owner's) or the 10 km block order; see `HANDOFF_STATION_3D.md`, Denmark.
`make_dk_bundle.py` + `station_pack.py` build the 3D pack from the 1 km tiles once they exist.

| File | What it is | Licence |
|---|---|---|
| `{slug}_platform_banedanmark.geojson` | One line per Bilag 3.6 row (perron, track, length, height in cm above rail) on Banedanmark's track centreline, cut to its platform outline; `geometry_how` says how each was placed; laser levels empty until the 3D pass | Bilag 3.6: Banedanmark's facts; geometry Banedanmark Open Data, CC BY 4.0 |
| `station_facts.json` | Part 2: levels, ways between levels, entrances, amenities (shops, cafés, kiosks…) with hours and positions, open points; each with `_source` | owner pages (facts only), OSM (ODbL) |

Register flags (not decided):
""" + ('\n'.join(f'- {x}' for x in R['flags']) if R['flags'] else '- none') + '\n'
    open(f'{d}/README.md', 'w').write(rd)
    json.dump({'clack_id': s['clack_id'], 'slug': slug, 'platforms': [], 'flags': R['flags'], 'note': 'register only; 3D pending'},
              open(f'{d}/_register_only.json', 'w'), ensure_ascii=False, indent=1)
    print(s['safe'], slug, len(feats))
