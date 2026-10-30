"""Parse Jernhusen 'Hitta din station' pages (saved by the browser as clack_jernhusen_pages_SE.json) into structured facts.

parse(station_record) -> {'address', 'halls': [{name, hours_raw, opening_hours}], 'shops': [{name, url, address, hours_raw, opening_hours}],
                          'sections': {page: text}, 'plans': [{title, url, size}]}
"""
import re
from bs4 import BeautifulSoup

DAYS = {'mån': 'Mo', 'man': 'Mo', 'måndag': 'Mo', 'tis': 'Tu', 'tisdag': 'Tu', 'ons': 'We', 'onsdag': 'We', 'tor': 'Th', 'tors': 'Th',
        'torsdag': 'Th', 'fre': 'Fr', 'fredag': 'Fr', 'lör': 'Sa', 'lördag': 'Sa', 'sön': 'Su', 'söndag': 'Su'}
NAV = {'På stationen', 'Mat och butiker', 'Tillgänglighet', 'Toalett', 'Wifi', 'Taxi', 'Förvaringsboxar', 'Porter', 'Hittegods',
       'Trafik och biljetter', 'Lounge', 'Karta över stationen', 'Karta över stationen (Google)', 'Hitta hit', 'Laddar...', 'Stationer'}


def lines(html):
    s = BeautifulSoup(html, 'html.parser')
    for t in s.find_all('br'):
        t.replace_with('\n')
    return [l.strip() for l in s.get_text('\n').split('\n') if l.strip()], s


def body(L):
    """Page body: after the breadcrumb, before the repeated 'På stationen' navigation."""
    try:
        end = L.index('På stationen')
    except ValueError:
        end = len(L)
    return L[3:end]


def tm(t):
    t = t.replace('.', ':')
    if ':' not in t:
        t = t + ':00'
    h, m = t.split(':')[:2]
    h = int(h)
    return f'{h:02d}:{int(m or 0):02d}'


def day(d):
    d = d.strip().lower().rstrip('.')
    for k in sorted(DAYS, key=len, reverse=True):
        if d.startswith(k):
            return DAYS[k]
    return None


def to_osm(raw_lines):
    """Swedish hours lines -> OSM opening_hours, or None if any line can't be read."""
    out = []
    for l in raw_lines:
        s = l.replace('–', '-').replace('—', '-').strip().rstrip('.')
        s = re.sub(r'\s+', ' ', s)
        lo = s.lower()
        m = re.match(r'^(alla dagar|dagligen|varje dag|mån-sön|måndag-söndag)\s*:?\s*(.*)$', lo)
        if m:
            days, rest = 'Mo-Su', m.group(2)
        else:
            m = re.match(r'^([a-zåäö]+)\s*(?:-\s*([a-zåäö]+))?\s*:?\s*(.*)$', lo)
            if not m or not day(m.group(1)):
                return None
            d1, d2 = day(m.group(1)), day(m.group(2)) if m.group(2) else None
            if m.group(2) and not d2:
                return None
            days, rest = (f'{d1}-{d2}' if d2 else d1), m.group(3)
        rest = rest.strip()
        if rest in ('stängt', 'stängd', 'closed'):
            out.append(f'{days} off')
            continue
        if rest in ('dygnet runt', 'öppet dygnet runt', '24h', '00-24'):
            out.append(f'{days} 00:00-24:00')
            continue
        tm_ = re.findall(r'(\d{1,2}(?:[.:]\d{2})?)\s*-\s*(\d{1,2}(?:[.:]\d{2})?)', rest)
        if not tm_:
            return None
        out.append(days + ' ' + ','.join(f'{tm(a)}-{tm(b)}' for a, b in tm_))
    return '; '.join(out) if out else None


HOURS_LINE = re.compile(r'^(alla dagar|dagligen|mån|tis|ons|tor|fre|lör|sön)[a-zåäö]*\b', re.I)


def parse(rec):
    out = {'name': rec['name'], 'url': rec['url'], 'read': rec['read'][:10], 'halls': [], 'shops': [], 'sections': {}, 'plans': []}
    L, _ = lines(rec['pages'][''])
    B = body(L)
    try:
        i = B.index('Hitta hit')
        out['address'] = ', '.join(B[i + 1:i + 3])
    except ValueError:
        pass
    if 'Öppettider' in B:
        i = B.index('Öppettider') + 1
        cur = None
        while i < len(B) and B[i] not in ('Trafikinfo',):
            if HOURS_LINE.match(B[i]):
                if cur is None:
                    cur = {'name': 'Stationen', 'hours_raw': []}
                    out['halls'].append(cur)
                cur['hours_raw'].append(B[i])
            else:
                cur = {'name': B[i], 'hours_raw': []}
                out['halls'].append(cur)
            i += 1
        for h in out['halls']:
            h['opening_hours'] = to_osm(h['hours_raw'])
    for p, html in rec['pages'].items():
        if not p:
            continue
        L, soup = lines(html)
        B = body(L)
        out['sections'][p.strip('/')] = '\n'.join(B)
        if p.startswith('mat-och-butiker'):
            out['shops'] = shops(B)
        if p.startswith('karta'):
            for a in soup.find_all('a'):
                href = a.get('href') or ''
                if href.lower().endswith('.pdf') or 'pdf' in href.lower() or 'google' in href:
                    out['plans'].append({'title': a.get_text(' ', strip=True), 'url': href})
    return out


def is_hours(l):
    return bool(HOURS_LINE.match(l) or re.match(r'^(stängt|.*\d{1,2}[.:]?\d{0,2}\s*[-–]\s*\d)', l, re.I)) and not l.startswith('www') and not is_phone(l)


URL = re.compile(r'^(www\.|https?://|[a-z0-9-]+(\.[a-z0-9-]+)*\.(se|com|nu|net|org|eu|dk|fi|no)\b)', re.I)
ADDR = re.compile(r'^[A-ZÅÄÖ][\wåäöÅÄÖé.&\' -]*\s\d+[A-Za-z]?(\s*[-,].*)?$')
isaddr = lambda l: bool(ADDR.match(l)) and not is_hours(l)
is_phone = lambda l: bool(re.match(r'^(\+?\d[\d \-]{6,})$', l))


def shops(B):
    try:
        i0 = B.index('Butiker') + 1
    except ValueError:
        i0 = 0
    B = B[i0:]
    LOC = re.compile(r'^[A-ZÅÄÖ][a-zåäö]+( [A-ZÅÄÖa-zåäö]+)? C$|^Centralstationen$')
    B = [l for n_, l in enumerate(B) if not (n_ > 0 and l == B[n_ - 1])]      # the name comes twice (logo text + title)
    starts = [k for k in range(len(B) - 1) if not LOC.match(B[k]) and not is_hours(B[k]) and not is_phone(B[k]) and B[k] != 'Öppettider'
              and not URL.match(B[k]) and not isaddr(B[k]) and (URL.match(B[k + 1]) or isaddr(B[k + 1]) or is_phone(B[k + 1]))]
    res = []
    for n, k in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(B)
        blk = B[k + 1:end]
        cur = {'name': B[k], 'url': None, 'address': None, 'hours_raw': [], 'units': []}
        unit = None
        for j, l in enumerate(blk):
            if URL.match(l):
                cur['url'] = cur['url'] or l
            elif is_hours(l):
                (unit['hours_raw'] if unit else cur['hours_raw']).append(l)
            elif isaddr(l) and not cur['hours_raw'] and not cur['units']:
                cur['address'] = cur['address'] or l
            elif is_phone(l) or l == 'Öppettider' or LOC.match(l):
                continue
            elif is_hours(l):
                (unit['hours_raw'] if unit else cur['hours_raw']).append(l)
            else:
                unit = {'where': l, 'hours_raw': []}
                cur['units'].append(unit)
        cur['units'] = [u for u in cur['units'] if u['hours_raw']]
        res.append(cur)
    for s in res:
        s['opening_hours'] = to_osm_checked(s['hours_raw'])
        for u in s['units']:
            u['opening_hours'] = to_osm_checked(u['hours_raw'])
    return res


def to_osm_checked(raw):
    """None when the lines repeat a day (two units' hours run together on the page)."""
    oh = to_osm(raw)
    if not oh:
        return None
    seen = set()
    order = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
    for part in oh.split('; '):
        d = part.split(' ')[0]
        a, b = (d.split('-') + [d])[:2]
        ia, ib = order.index(a), order.index(b)
        days = {order[(ia + k) % 7] for k in range((ib - ia) % 7 + 1)}
        if days & seen:
            return None
        seen |= days
    return oh


def hours_for(name, rec):
    """Fallback: read the hours that follow a shop's name on the 'Mat och butiker' page."""
    page = next((h for p, h in rec['pages'].items() if p.startswith('mat')), None)
    if not page:
        return None
    L, _ = lines(page)
    B = body(L)
    key = re.sub(r'[^a-z0-9]', '', name.lower())
    for i, l in enumerate(B):
        if re.sub(r'[^a-z0-9]', '', l.lower()) != key:
            continue
        try:
            j = B.index('Öppettider', i, i + 8) + 1
        except ValueError:
            continue
        units, cur = [], {'where': None, 'hours_raw': []}
        units.append(cur)
        while j < len(B) and j < i + 30:
            x = B[j]
            if x == 'Öppettider':
                break
            if is_hours(x):
                cur['hours_raw'].append(x)
            elif is_phone(x):
                pass
            elif j + 1 < len(B) and is_hours(B[j + 1]) and len(x) < 60:
                cur = {'where': x, 'hours_raw': []}
                units.append(cur)
            else:
                break
            j += 1
        units = [u for u in units if u['hours_raw']]
        for u in units:
            u['opening_hours'] = to_osm_checked(u['hours_raw'])
        if units:
            return units
    return None


if __name__ == '__main__':
    import json, sys
    J = json.load(open(sys.argv[1]))
    r = parse(J[sys.argv[2]])
    print(json.dumps({k: v for k, v in r.items() if k != 'sections'}, ensure_ascii=False, indent=1)[:5000])
    print(list(r['sections']))
