"""Join JNB 2027 Bilaga 2A tab 4 rows with BanInfo Plattform objects into trafikverket_platforms_SE.csv."""
import csv, re, sys

NAMES = {
 '740000002': 'Göteborgs central', '740000001': 'Stockholms central', '740000004': 'Alvesta', '740000556': 'Arlanda C',
 '740000937': 'Burlöv', '740000170': 'Eskilstuna central', '740000060': 'Falköpings central', '740000031': 'Flemingsberg',
 '740000210': 'Gävle central', '740000077': 'Hallsbergs personbangård', '740000040': 'Herrljunga central', '740001586': 'Hyllie',
 '740000006': 'Hässleholm', '740000090': 'Jönköpings central', '740000070': 'Karlstad C', '740000166': 'Katrineholms central',
 '740000206': 'Kil', '740000192': 'Kumla', '740000009': 'Linköpings central', '740000120': 'Lund c', '740000003': 'Malmö central',
 '740000007': 'Norrköpings central', '740000140': 'Nässjö central', '740000008': 'Skövde central', '740000055': 'Södertälje syd',
 '740001587': 'Triangeln', '740000191': 'Trollhättan', '740000005': 'Uppsala central', '740000110': 'Varberg',
 '740000099': 'Västerås central', '740000133': 'Örebro central', '740000361': 'Örebro södra', '740000173': 'Öxnered'}
SUB = {'902': 'Södertälje syd undre', '903': 'Södertälje syd undre', '904': 'Södertälje syd övre', '905': 'Södertälje syd övre'}
H = {'låg': 0.35, 'mellan': 0.58, 'hög': 0.73, 'tsd mellan': 0.55, 'tsd hög': 0.76}
ORDER = list(NAMES)

# BanInfo objects that belong to another station or are not part of these stations: left out of the CSV (see README)
EXCLUDE = {('740000001', '2308'): 'Stockholm City (Citybanan), separate station',
           ('740000001', '2309'): 'Stockholm City (Citybanan), separate station'}
NOTE = {('740000170', '2489'): 'BanInfo only; about 0.7 km NW of the station building, not in Bilaga 2A',
        ('740000170', '2490'): 'BanInfo only; about 0.9 km NW of the station building, not in Bilaga 2A',
        ('740000005', '2335'): 'BanInfo only; track z10 on another line (km 114+), not in Bilaga 2A',
        ('740000005', '2336'): 'BanInfo only; track z9 on another line (km 114+), not in Bilaga 2A',
        ('740000002', '2622'): 'BanInfo only; valid from 2026-10-29, newer than Bilaga 2A (report 2026-02-04)',
        ('740000002', '2623'): 'BanInfo only; valid from 2026-10-29, newer than Bilaga 2A (report 2026-02-04)',
        ('740000556', '2305'): 'BanInfo only; Arlandabanan is not in Bilaga 2A; BanInfo gives no length, width or roof',
        ('740000556', '2306'): 'BanInfo only; Arlandabanan is not in Bilaga 2A; BanInfo gives no length, width or roof; 0.3 km N of Arlanda C point, check which station',
        ('740000556', '2307'): 'BanInfo only; Arlandabanan is not in Bilaga 2A; BanInfo gives no length, width or roof',
        ('740000361', '1219'): 'BanInfo only; not in Bilaga 2A (row 1141 lists tracks 2,30); see tab 5: middle platform to be removed',
        ('740000361', '2618'): 'BanInfo only; new side platform at track 30 (Bilaga tab 5, planned start 2026-05-30), valid from 2026-06-26'}


def rows(path):
    for line in open(path, encoding='utf-8'):
        if line.startswith('#') or line.startswith('clack_id') or not line.strip():
            continue
        yield line.rstrip('\n').split('|')


def tracks(s):
    return {t.strip().lower() for t in s.split(',') if t.strip() and t.strip() != '?'}


def track_overlap(a, b):
    for x in a:
        for y in b:
            if x == y or x.rstrip('abns') == y.rstrip('abns') and x.rstrip('abns'):
                return True
    return False


reg = [dict(zip(['sfx', 'bandel', 'tracks', 'cls', 'len', 'roof', 'zone', 'rem', 'row'], r)) for r in rows(sys.argv[1])]
for r in reg:
    r['id'] = next(i for i in NAMES if i.endswith(r['sfx']))
bi = [dict(zip('id bis tracks hojd beskr langd bredd tak zone kant bel kmf kmt vf seg lon lat'.split(), r)) for r in rows(sys.argv[2])]

used = set()
out = []
for r in reg:
    cands = [b for b in bi if b['id'] == r['id'] and (b['id'], b['bis']) not in used
             and b['hojd'].lower() == r['cls'].lower() and abs(float(b['langd'] or 0) - float(r['len'])) <= 1.0]
    best = [b for b in cands if track_overlap(tracks(b['tracks']), tracks(r['tracks']))] or cands
    best.sort(key=lambda b: abs(float(b['langd'] or 0) - float(r['len'])))
    if len(best) > 1 and abs(float(best[0]['langd']) - float(r['len'])) < abs(float(best[1]['langd']) - float(r['len'])):
        best = best[:1]
    b = best[0] if len(best) >= 1 else None
    if b is None and r['row'] == '833':
        r['rem'] += ' / same platform as row 828 (listed twice in Bilaga 2A)'
    rem = [r['rem']] if r['rem'] else []
    if b:
        used.add((b['id'], b['bis']))
        if len(best) > 1:
            rem.append('BanInfo match ambiguous: ' + '/'.join(x['bis'] for x in best))
    else:
        rem.append('no BanInfo object matched (missed by the pixel sampling or not in BanInfo)')
    if r['cls'] == 'ej norm':
        rem.append('class "ej norm" has no height in the key; height_m left empty')
    out.append(dict(clack_id=r['id'], station_name=SUB.get(r['row'], NAMES[r['id']]), bandel=r['bandel'], tracks=r['tracks'],
                    bis_object=b['bis'] if b else '', height_class=r['cls'], height_m=H.get(r['cls'].lower(), ''),
                    length_m=r['len'], width_m=(b['bredd'] if b and b['bredd'] not in ('0', '?') else ''),
                    roof=r['roof'], valid_from=(f"{b['vf'][:4]}-{b['vf'][4:6]}-{b['vf'][6:]}" if b else ''),
                    source_row=f"Bilaga 2A tab 4 row {r['row']}" + (f"; BanInfo BIS {b['bis']} (track {b['tracks']})" if b else ''),
                    remark='; '.join(rem)))

for b in bi:
    k = (b['id'], b['bis'])
    if k in used or k in EXCLUDE:
        continue
    cls = b['hojd'] if b['hojd'] != 'ej norm' else 'ej norm'
    out.append(dict(clack_id=b['id'], station_name=NAMES[b['id']], bandel='', tracks=b['tracks'] if b['tracks'] != '?' else '',
                    bis_object=b['bis'], height_class=cls, height_m=H.get(cls.lower(), ''),
                    length_m=b['langd'] if b['langd'] != '0' else '', width_m=b['bredd'] if b['bredd'] not in ('0', '?') else '',
                    roof=b['tak'] if b['tak'] != '?' else '', valid_from=f"{b['vf'][:4]}-{b['vf'][4:6]}-{b['vf'][6:]}",
                    source_row=f"BanInfo BIS {b['bis']}", remark=NOTE.get(k, 'BanInfo only; no matching Bilaga 2A row')))

out.sort(key=lambda o: (ORDER.index(o['clack_id']), o['source_row'].startswith('BanInfo'), o['source_row']))
cols = 'clack_id,station_name,bandel,tracks,bis_object,height_class,height_m,length_m,width_m,roof,valid_from,source_row,remark'.split(',')
with open(sys.argv[3], 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, cols)
    w.writeheader()
    w.writerows(out)
print(len(out), 'rows;', sum(1 for o in out if o['bis_object'] == ''), 'without BanInfo;',
      sum(1 for o in out if o['source_row'].startswith('BanInfo')), 'BanInfo only')
for o in out:
    if 'no BanInfo' in o['remark'] or 'ambiguous' in o['remark']:
        print(' ', o['clack_id'], o['tracks'], o['height_class'], o['length_m'], o['remark'])
