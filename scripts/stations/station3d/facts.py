"""Build station_facts.json for one station.

python3 facts.py <clack id> <out dir>
Inputs (paths below): Jernhusen pages, the app's station map (to match its POIs), the open-questions list,
OSM station elements (Overpass, when present), the 3D pack (platform sides from the laser), and the hand-read
facts in facts_manual/<id>.json (from plans and photos, each with its source).
"""
import json, sys, os, re, math, unicodedata
import jernhusen as JH

CID, OUT = sys.argv[1], sys.argv[2]
TODAY = '2026-10-30'
JPAGES = {}
R = os.environ.get('STATION3D_RESEARCH', 'data/stations/research')
HERE = os.path.dirname(os.path.abspath(__file__))
for f in (f'{R}/_sources/clack_jernhusen_pages_SE.json', f'{R}/_sources/clack_jernhusen_pages_SE_2.json'):
    if os.path.exists(f):
        for k, v in json.load(open(f)).items():
            if any(len(h) > 500 for h in v['pages'].values()):
                JPAGES[k] = v
APP = f'data/stations/{CID}.json'
OSMF = f'{R}/_sources/osm/{CID}.json'          # made by osm_station.py from an OSM API 0.6 map extract
PACK = f'{R}/{CID}'
MANUAL = f'{HERE}/facts_manual/{CID}.json'
OQ = f'{R}/STATION_OPEN_QUESTIONS_SWEDEN.md'

norm = lambda s: re.sub(r'[^a-z0-9]', '', unicodedata.normalize('NFKD', (s or '').lower()).encode('ascii', 'ignore').decode())
facts = {'clack_id': CID, 'compiled': TODAY, 'levels': [], 'platform_sides': [], 'connections': [], 'entrances': [], 'amenities': [],
         'plans': [], 'open': [], '_sources': {}}
manual = json.load(open(MANUAL)) if os.path.exists(MANUAL) else {}

# ---------------------------------------------------------------- open questions for this station
oq = []
blk = None
for line in open(OQ, encoding='utf-8'):
    m = re.match(r'^## .*\(`(\d+)`\)', line)
    if m:
        blk = m.group(1)
        continue
    if line.startswith('## '):
        blk = None
    if blk == CID and line.startswith('- '):
        oq.append(line[2:].strip())
facts['_open_questions_in'] = oq

# ---------------------------------------------------------------- Jernhusen
J = JH.parse(JPAGES[CID]) if CID in JPAGES else None
jsrc = lambda page='': (J['url'] + page) if J else None
if J:
    facts['_sources']['jernhusen'] = {'url': J['url'], 'read': J['read'], 'licence': 'Jernhusen website: facts only, not copied'}
    for h in J['halls']:
        if h['hours_raw']:
            facts['amenities'].append({'category': 'station_hall', 'name': h['name'], 'level': None, 'where': None,
                                       'opening_hours': h['opening_hours'], 'hours_raw': '; '.join(h['hours_raw']) if not h['opening_hours'] else None,
                                       'hours_source': 'website (Jernhusen)', 'hours_checked': J['read'], '_source': J['url']})
    for p in J['plans']:
        if 'google.com' in p['url']:
            continue
        facts['plans'].append({'title': re.sub(r'\s*\(\s*pdf.*', '', p['title']).strip() or p['url'].rsplit('/', 1)[-1],
                               'publisher': 'Jernhusen' if 'datocms' in p['url'] else p['url'].split('/')[2],
                               'url': p['url'], 'licence': 'not open: facts only', 'read': J['read'], 'linked_from': jsrc('karta-over-stationen/')})
    CAT = {'toalett': 'toilets', 'forvaringsboxar': 'luggage_locker', 'fovaringsboxar': 'luggage_locker', 'lounge': 'lounge',
           'trafik-och-biljetter': 'ticket_office', 'taxi': 'taxi', 'taxi-och-biluthyrning': 'taxi', 'parkering': 'parking',
           'uttagsautomat': 'atm', 'fotoautomat': 'photo_booth', 'porter': 'porter', 'wifi': 'wifi', 'tillganglighet': 'accessibility',
           'hittegods': 'lost_property'}
    for name, sec in J['sections'].items():
        if name not in CAT:
            continue
        L = [l for l in sec.split('\n')[2:] if l.strip()]
        text = ' '.join(L)
        hrs = [l for l in L if JH.HOURS_LINE.match(l)]
        oh = JH.to_osm_checked(hrs) if hrs and CAT[name] in ('toilets', 'luggage_locker') else None
        fee = re.findall(r'(\d+\s*kr[^.;]*)', text)
        facts['amenities'].append({'category': CAT[name], 'name': L[0] if L else name, 'owner_text': text[:900],
                                   'fee': '; '.join(fee[:4]) if fee else ('free' if re.search(r'gratis|kostnadsfri', text, re.I) else None),
                                   'opening_hours': oh, 'hours_raw': ('; '.join(hrs) + ' (hours named in the text; see owner_text for what they belong to)') if hrs and not oh else None,
                                   'hours_source': 'website (Jernhusen)' if hrs else None, 'hours_checked': J['read'] if hrs else None,
                                   'level': None, 'where': None, '_source': J['url'] + name + '/',
                                   'note': "Jernhusen's own words (Swedish), kept so the place and conditions can be read; 'where' is in the text when given"})

# ---------------------------------------------------------------- the app's POIs and their hours
app = json.load(open(APP)) if os.path.exists(APP) else None
levels_app = {l['id']: l['name'] for l in (app or {}).get('levels', [])}
shops = {norm(s['name']): s for s in (J['shops'] if J else [])}
for s in (J['shops'] if J else []):
    shops.setdefault(norm(re.sub(r'\s+(centralplan|centralstation|central|stockholm|göteborg|malmö).*$', '', s['name'], flags=re.I)), s)
for a in manual.get('amenities', []):
    if a.get('hours_by_unit') and a.get('name'):
        shops[norm(a['name'])] = {'name': a['name'] + ' (manual)', 'opening_hours': None, 'hours_raw': [], 'url': None,
                                  'units': [{'where': u['where'], 'opening_hours': u['opening_hours']} for u in a['hours_by_unit']]}
plan_level = manual.get('shop_levels', {})         # name -> level name, read from the owner's plan
matched = set()
for p in (app or {}).get('pois', []):
    if not p.get('name'):
        continue
    key = norm(p['name'])
    s = shops.get(key) or next((v for k, v in shops.items() if key and (k.startswith(key) or key.startswith(k)) and min(len(k), len(key)) >= 5), None)
    if not s:
        tk = set(re.findall(r'[a-z0-9]+', unicodedata.normalize('NFKD', p['name'].lower()).encode('ascii', 'ignore').decode())) - {'cafe', 'the', 'och', 'and', 'ab'}
        best = None
        for v in {id(x): x for x in shops.values()}.values():
            tv = set(re.findall(r'[a-z0-9]+', unicodedata.normalize('NFKD', v['name'].lower()).encode('ascii', 'ignore').decode())) - {'cafe', 'the', 'och', 'and', 'ab'}
            if tk and tv:
                j = len(tk & tv) / len(tk | tv)
                if j >= 0.6 and (best is None or j > best[0]):
                    best = (j, v)
        s = best[1] if best else None
    entry = {'category': p['category'], 'name': p['name'], 'app_poi': p['id'], 'level': p.get('level'), 'level_name': levels_app.get(p.get('level')),
             'where': None}
    pl = plan_level.get(p['name']) or plan_level.get(s['name'] if s else '')
    if pl:
        entry['level_per_plan'] = pl['level']
        entry['where'] = pl.get('where')
        entry['level_source'] = pl['_source']
    if s:
        matched.add(s['name'])
        oh, raw, unitw = s['opening_hours'], ('; '.join(s['hours_raw']) or None), None
        if s.get('units'):
            al = [a.lower() for a in manual.get('hall_aliases', {}).get(p.get('level'), [])]
            hit = [u for u in s['units'] if any(a in u['where'].lower() for a in al)]
            if len(hit) == 1:
                oh, unitw = hit[0]['opening_hours'], hit[0]['where']
            elif len(s['units']) == 1:
                oh, unitw = s['units'][0]['opening_hours'], s['units'][0]['where']
            else:
                entry['hours_by_unit'] = [{'where': u['where'], 'opening_hours': u['opening_hours'], 'hours_raw': '; '.join(u.get('hours_raw', []))} for u in s['units']]
        entry.update(opening_hours=oh, hours_raw=None if oh else raw, hours_source='website (Jernhusen station page)',
                     hours_checked=J['read'], _source=jsrc('mat-och-butiker/'))
        if unitw:
            entry['hours_unit'] = f'Jernhusen lists this brand in several places; these are the hours for "{unitw}"'
        if s.get('url'):
            entry['website'] = s['url']
    elif J and JH.hours_for(p['name'], JPAGES[CID]):
        units = JH.hours_for(p['name'], JPAGES[CID])
        if len(units) == 1:
            entry.update(opening_hours=units[0]['opening_hours'], hours_raw=None if units[0]['opening_hours'] else '; '.join(units[0]['hours_raw']))
        else:
            entry.update(opening_hours=None, hours_by_unit=[{'where': u['where'], 'opening_hours': u['opening_hours'], 'hours_raw': '; '.join(u['hours_raw'])} for u in units])
        entry.update(hours_source='website (Jernhusen station page)', hours_checked=J['read'], _source=jsrc('mat-och-butiker/'))
    elif p.get('opening_hours'):
        entry.update(opening_hours=p['opening_hours'], hours_source=p.get('hours_source'), hours_checked=p.get('hours_verified'),
                     _source='the app map (' + str(p.get('hours_source')) + ')')
    else:
        entry.update(opening_hours=None, _source=None)
    facts['amenities'].append(entry)
for s in (J['shops'] if J else []):
    if s['name'] in matched:
        continue
    pl = plan_level.get(s['name'])
    if s.get('units'):
        s = dict(s, hours_by_unit=[{'where': u['where'], 'opening_hours': u['opening_hours']} for u in s['units']])
    facts['amenities'].append({'category': None, 'name': s['name'], 'app_poi': None, 'level': None, 'hours_by_unit': s.get('hours_by_unit'),
                               'level_per_plan': pl['level'] if pl else None, 'where': pl.get('where') if pl else None,
                               'level_source': pl['_source'] if pl else None,
                               'opening_hours': s['opening_hours'], 'hours_raw': None if s['opening_hours'] else '; '.join(s['hours_raw']),
                               'hours_source': 'website (Jernhusen station page)', 'hours_checked': J['read'], 'website': s.get('url'),
                               '_source': jsrc('mat-och-butiker/'), 'note': 'listed by Jernhusen, not in the app map'})

# ---------------------------------------------------------------- platform sides from the laser + BanInfo
gj = next((f for f in os.listdir(PACK) if f.endswith('_platform_trafikverket.geojson')), None) if os.path.isdir(PACK) else None
rep = json.load(open(f'{PACK}/_report.json')) if os.path.isdir(PACK) else None
if gj and rep:
    from pyproj import Transformer
    fw = Transformer.from_crs(4326, 3006, always_xy=True).transform
    G = json.load(open(f'{PACK}/{gj}'))
    byb = {r['bis_object']: r for r in rep['platforms']}
    for f in G['features']:
        q = f['properties']
        r = byb.get(q['bis_object'])
        if not r or not r.get('platform_side'):
            continue
        pts = [fw(*c) for c in f['geometry']['coordinates']]
        mid = len(pts) // 2
        a, b = pts[max(mid - 1, 0)], pts[min(mid + 1, len(pts) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        nx, ny = -ty, tx                     # left normal
        if r['platform_side'] == 'right':
            nx, ny = -nx, -ny
        ang = (math.degrees(math.atan2(nx, ny)) + 360) % 360
        comp = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'][int((ang + 22.5) // 45) % 8]
        e = {'platform_bis': q['bis_object'], 'track': q.get('track'), 'side': comp,
             'meaning': f'the platform lies on the {comp} side of track {q.get("track")} (the train stops with the platform to its {comp})',
             '_source': f"laser ({rep['laser']['scan_date']}, raised ground beside the BanInfo track line) + Trafikverket BanInfo BIS {q['bis_object']}; read {TODAY}"}
        if r.get('side_note'):
            e['note'] = r['side_note']
        facts['platform_sides'].append(e)

# ---------------------------------------------------------------- OSM (connections, entrances, amenities the owner pages lack)
if os.path.exists(OSMF):
    O = json.load(open(OSMF))
    facts['_sources']['osm'] = {'what': O['source'], 'read': TODAY, 'licence': 'ODbL'}
    for c in O['connections']:
        if c['kind'] in ('lift', 'escalator') or c.get('reaches_platforms'):
            facts['connections'].append({'kind': c['kind'], 'osm_id': c['osm_id'], 'name': c.get('name'), 'osm_level': c.get('level'),
                                         'between': (['platform ' + r for r in c['reaches_platforms']] or None),
                                         'wheelchair': c.get('wheelchair'), 'conveying': c.get('conveying'), 'length_m': c.get('length_m'),
                                         'where': None, 'confirmed_by': 'OSM only',
                                         '_source': f"OSM {c['osm_id']} (read {TODAY}); 'between' = OSM platforms within 6–10 m of it"})
    for e in O['entrances']:
        facts['entrances'].append({'name': e.get('name'), 'osm_id': e['osm_id'], 'street': e.get('addr_street') or e.get('nearest_named_street'),
                                   'street_how': 'addr:street' if e.get('addr_street') else ('nearest named street, %s m' % e.get('nearest_street_m') if e.get('nearest_named_street') else None),
                                   'level': e.get('level'), 'kind': e.get('entrance'), 'wheelchair': e.get('wheelchair'), 'door': e.get('door'),
                                   '_source': f"OSM {e['osm_id']} (already in OSM)"})
    for m_ in O['amenities']:
        if m_['category'] in ('toilets', 'locker', 'luggage_locker', 'left_luggage', 'waiting_room', 'ticket_validator', 'vending=public_transport_tickets', 'shop=ticket'):
            facts['amenities'].append({'category': m_['category'], 'name': m_.get('name'), 'osm_id': m_['osm_id'], 'osm_level': m_.get('level'),
                                       'fee': m_.get('fee'), 'opening_hours': m_.get('opening_hours'),
                                       'hours_source': "OSM's opening_hours" if m_.get('opening_hours') else None,
                                       '_source': f"OSM {m_['osm_id']} (read {TODAY})"})

# ---------------------------------------------------------------- hand-read facts (plans, photos)
for k in ('levels', 'connections', 'entrances', 'amenities', 'plans', 'platform_sides'):
    facts[k] = manual.get(k, []) + facts[k]
# ---------------------------------------------------------------- positions of shops/food/services from OSM (for the 2D map)
SHOPLIKE = {'cafe', 'restaurant', 'fast_food', 'bar', 'pub', 'pharmacy', 'atm', 'bank', 'ice_cream', 'bureau_de_change',
            'post_office', 'car_rental', 'money_transfer', 'food_court', 'kiosk', 'shop', None}
OSM_SHOPLIKE = lambda c: c and ((c.startswith('shop=') and c != 'shop=ticket') or c in SHOPLIKE)
if os.path.exists(OSMF):
    tok = lambda s: set(re.findall(r'[a-z0-9]+', unicodedata.normalize('NFKD', (s or '').lower()).encode('ascii', 'ignore').decode())) - {'cafe', 'the', 'och', 'and', 'ab', 'station', 'c'}
    osm_s = [m_ for m_ in O['amenities'] if OSM_SHOPLIKE(m_['category']) and (m_.get('name') or m_.get('brand'))]
    used_osm = set()

    def osm_matches(name):
        k, tk = norm(name), tok(name)
        out = []
        for m_ in osm_s:
            for nm in {m_.get('name'), m_.get('brand')} - {None}:
                k2, t2 = norm(nm), tok(nm)
                if k2 == k or (min(len(k), len(k2)) >= 5 and (k.startswith(k2) or k2.startswith(k))) or (tk and t2 and len(tk & t2) / len(tk | t2) >= 0.6):
                    out.append(m_)
                    break
        return out

    def pos(m_):
        return {'lon': m_['lonlat'][0], 'lat': m_['lonlat'][1], 'osm_id': m_['osm_id'], 'osm_level': m_.get('level'),
                'in_station_building': m_.get('in_station_building'), 'to_nearest_platform_m': m_.get('to_nearest_platform_m'),
                'how': ('representative point of the OSM area ' if m_.get('drawn_as') == 'area' else 'OSM node ') + m_['osm_id'],
                '_source': f"OpenStreetMap {m_['osm_id']} (ODbL), read {TODAY}"}
    for a in facts['amenities']:
        if not a.get('name') or a.get('position') or a.get('category') not in SHOPLIKE | {'shop'} and not str(a.get('category')).startswith('shop'):
            continue
        direct = [m_ for m_ in osm_s if a.get('app_poi') and a['app_poi'].replace('osm', 'n') == m_['osm_id']]
        cands = direct or osm_matches(a['name'])
        if len(cands) == 1:
            a['position'] = pos(cands[0])
            used_osm.add(cands[0]['osm_id'])
        elif cands:
            same = sum(1 for b in facts['amenities'] if b.get('name') == a['name'])
            a['position_candidates'] = [pos(m_) for m_ in cands]
            a['position_note'] = (f"OSM has {len(cands)} places with this name at the station; which one this entry is isn't settled"
                                  + ('' if same == 1 else f" (this name appears {same} times in the list)"))
            used_osm.update(m_['osm_id'] for m_ in cands)
        else:
            a['position'] = None
            a['position_note'] = 'not found in OSM near the station: position unknown'
    for m_ in osm_s:
        if m_['osm_id'] in used_osm:
            continue
        facts['amenities'].append({'category': m_['category'].replace('shop=', '') if m_['category'].startswith('shop=') else m_['category'],
                                   'name': m_.get('name') or m_.get('brand'), 'brand': m_.get('brand'), 'cuisine': m_.get('cuisine'),
                                   'opening_hours': m_.get('opening_hours'),
                                   'hours_source': "OSM's opening_hours" if m_.get('opening_hours') else None,
                                   'hours_checked': TODAY if m_.get('opening_hours') else None,
                                   'website': m_.get('website') or m_.get('contact:website'), 'position': pos(m_),
                                   'note': 'OSM only: not on the station owner\'s list; check it still exists' if J else 'from OSM (the station owner publishes no shop list)',
                                   '_source': f"OpenStreetMap {m_['osm_id']} (ODbL), read {TODAY}"})
    for k in ('connections', 'entrances'):
        for e in facts[k]:
            m_ = next((c for c in O[k] if c['osm_id'] == e.get('osm_id')), None)
            if m_ and m_.get('lonlat') and 'position' not in e:
                e['position'] = {'lon': m_['lonlat'][0], 'lat': m_['lonlat'][1], 'how': 'OSM ' + m_['osm_id'] + (' (point on the way)' if m_['osm_id'][0] == 'w' else ''),
                                 '_source': f"OpenStreetMap {m_['osm_id']} (ODbL), read {TODAY}"}
    for e in facts['amenities']:
        if e.get('osm_id') and 'position' not in e:
            m_ = next((c for c in O['amenities'] if c['osm_id'] == e['osm_id']), None)
            if m_ and m_.get('lonlat'):
                e['position'] = pos(m_)
facts['answers'] = manual.get('answers', [])
facts['open'] = manual.get('open', [])
# open questions about hours: settled if the POI now has hours
for q in oq:
    m = re.match(r'^(\w+) (.+): no opening hours$', q)
    if m:
        hit = [a for a in facts['amenities'] if a.get('name') == m.group(2) and (a.get('opening_hours') or a.get('hours_raw')
               or any(u.get('opening_hours') or u.get('hours_raw') for u in (a.get('hours_by_unit') or [])))]
        if not hit and not any(m.group(2) in o for o in facts['open']):
            facts['open'].append(f"{q}: not on the owner's page and no other source found")
os.makedirs(OUT, exist_ok=True)
json.dump(facts, open(f'{OUT}/station_facts.json', 'w'), ensure_ascii=False, indent=1)
n_h = sum(1 for a in facts['amenities'] if a.get('opening_hours'))
print(CID, 'levels', len(facts['levels']), 'sides', len(facts['platform_sides']), 'connections', len(facts['connections']),
      'entrances', len(facts['entrances']), 'amenities', len(facts['amenities']), 'with hours', n_h, 'plans', len(facts['plans']), 'open', len(facts['open']))
