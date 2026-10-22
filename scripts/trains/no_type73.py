"""NSB/Norske Tog Type 73 Signatur (Adtranz, 4 cars), cab car BM 73. docs/TRAIN_ART.md; x3.py is the worked example.

Who runs it and in what livery (checked 2026-10-22):
- SJ Nord (sets 03, 06, 07, 09, 11, 14; no.wikipedia "Type 73 (motorvognsett)"): navy front, silver body, a red
  diagonal stripe. Seen in service in Aug 2026 (Flickr 55485812179, BM 73 003) and July 2024 (53848497575).
  Drawn: `sj-nord`. Some sets carry temporary wraps (Peer Gynt, Kvitfjell, Pride); those are not the livery.
- Go-Ahead Norge (sets 01, 02, 04, 05, 08, 12, 15, 16): all dark blue with lighter blue diagonal stripes on the cab
  cars (Flickr 55485752348, Aug 2026; Norske Tog photo 73-16_GA-1). No side-on photo of a Go-Ahead cab car was found,
  so the stripes can't be placed: NOT drawn (shows unpainted).
- Vy (the six 73B sets, 41-46): being repainted from NSB red to Vy green and black (jernbane.net: 73-45 green
  2025-04-07, 73-41 "nylakkert i svart og grønt" 2025-05-23, 73-44 and 73-42/43 still red in May 2025; only 41 and
  45 seen green in 2026). Mid-repaint: NOT drawn (shows unpainted).

Sources (all retrieved 2026-10-22):
- A. Side-on photo, SJ Nord BFM 73 111 at Otta, 2024-07-09, Flickr "Kurbelwelle"
  https://www.flickr.com/photos/kurbelwelle/53848497575 (1024 px). Nose, cab, red stripe, navy edge, roof and waist
  bands. Nose tip x=867 px, roof y=282, sill (bottom of the painted body) y=496, rail y=576; 79 px/m (roof to rail
  3.70 m, no.wikipedia; front bogie axles 216 px apart = 2.7 m).
- B. Side-on photo of a whole BM 73 (73 009, old blue livery, same body), Holten NL 2014-05-11, Flickr "J. Zwoferink"
  https://www.flickr.com/photos/.../13974008849 (1024 px). Door and window positions along the car. Nose tip x=927,
  car end x=78 (27.93 m, no.wikipedia "Endevognene er 27,9 meter"), 30.4 px/m; roof y=335, sill y=418.
- C. Near side-on 350 px photo, SJ Nord BM 73 014 at Oslo S 2023-06-11, jernbane.net image 290733 (Knut Erik Hagen):
  confirms the BM end has the same navy front and red stripe at the same distance from the nose as the BFM end in A.
- D. Norske Tog car drawing type73-BM73A.svg (norsketog.no/tog/motorvognsett/type-73-serie-a): pane count only (it is
  not to scale: its bogies and nose are stylised).
- no.wikipedia Type 73: end cars 27.9 m, wheels 870 mm, height 3.7 m.

Measured (metres from the nose tip; fractions of roof-to-sill height, 2.71 m):
- From A: roof flat to 2.35 m, then (2.15, .04) (1.95, .075) (1.65, .16) (1.44, .22) (1.14, .29) (0.94, .335)
  (0.73, .40) (0.53, .45) (0.23, .53) (0.13, .57) (0.03, .63); front face vertical .63-.83; nose bottom (0.12, 1.0).
  Windscreen (1.96, .10) (1.08, .30) (1.35, .31) (2.01, .21). Cab side window front edge (2.52, .36) (1.89, .46)
  (1.91, .57) (2.11, .645) (2.27, .69). Window band .374-.70. Cab module seam 4.04 m. Under-nose fairing from the sill
  at 2.2 m down to 1.27 at 1.28 m, front at 0.13 m; yellow strip 1.235-1.27 from 1.28 to 0.15 m. Skirt to 1.26.
  Front bogie: axles 3.54 and 6.28 m (centre 4.91). Wheel centre 0.435 m above rail; rail at 1.373.
- Red stripe (sj-nord): straight, 45 deg; its rear edge R(f) = 4.11 + 2.852 * (0.8785 - f) m, i.e. 6.38 m at the top
  of the side (.084) and 3.76 m at the sill; 0.19 m wide; a 0.11 m silver gap, then navy to the nose. Navy covers the
  roof from the cab seam (4.04 m) forward. Rows traced in A: red 406-420 px at y=340, 542-558 at y=470, 564-580 at 490.
- Roof-edge band 0-.084 and waist band .70-.81: light grey diagonal hatch (A), periods 0.33 m and 0.23 m; four red
  dashes just behind the red stripe in the waist band (A, C).
- From B: cab side glass from 2.0 m, seam 2.8 m, pillar 4.18 m, pillar 6.2-6.48; door 6.48-7.96 m; band 7.96-18.55;
  door 18.55-20.26; glazed 20.3-25.4 m, dark panel to 27.7 m; car end 27.93 m. Doors .24-1.09; rear bogie centre 23.7 m.
  Pane counts from D: 4 between the doors, 2 behind the rear door.
- Not drawn: roof antennas (too small), lettering and logos, door colours (C and the 2026 photo disagree).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

SJ = 'sj-nord'
d = Drawing(car_m=27.93, body_m=2.71, gangway_m=0.5, liveries=[SJ])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('navy', ['#2c3a5c', '#1f2a44', '#18213a'])
d.gradient('sjred', ['#e4475f', '#d63a52'])


def P(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


WIN = (0.374, 0.70)
DOOR = (0.24, 1.09)
RAIL = 1.373
WHEEL_R = 0.435


def R(f):
    """Rear edge of the SJ Nord red stripe, metres from the tip, at height f."""
    return 4.11 + 2.852 * (0.8785 - f)


def bogie(cm, axle_m=2.7):
    """The kit's bogie, drawn at the measured wheel height (the kit's sits a fixed 13 units under the sill)."""
    cx, cy = x(cm), y(RAIL) - WHEEL_R * M
    s, r = axle_m * M / 2, WHEEL_R * M
    d.add(f'<rect x="{cx - s - 14:.1f}" y="{cy - 13:.1f}" width="{2 * s + 28:.1f}" height="11" rx="3" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>')
    for dx in (-s, s):
        d.add(f'<circle cx="{cx + dx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
        d.add(f'<circle cx="{cx + dx:.1f}" cy="{cy:.1f}" r="5" fill="#6d7681"/>')
    d.add(f'<line x1="{cx - 12:.1f}" y1="{cy - 7:.1f}" x2="{cx + 12:.1f}" y2="{cy - 10:.1f}" stroke="#6d7681" stroke-width="2.4" stroke-linecap="round"/>')


def hatch(m_from, m_to, f0, f1, period, width, colour, only):
    """Diagonal stripes leaning toward the nose, as one path, between m_from (rear) and m_to (front)."""
    lean = (f1 - f0) * d.H / M  # 45 degrees: the top is this many metres nearer the nose
    parts = []
    m = m_from
    while m - width > m_to:
        a, b = m, m - width
        parts.append(f'M{P(a, f1)} L{P(b, f1)} L{P(b - lean, f0)} L{P(a - lean, f0)} Z')
        m -= period
    d.paint(f'<path d="{" ".join(parts)}" fill="{colour}"/>', only)


# Underframe skirt between the bogie openings (B: 25.8-21.4 m and A: 7.16-2.2 m); fairing under the nose (A).
SKIRT = 1.26
for a, b in ((27.75, 25.8), (21.4, 7.16)):
    d.add(f'<rect x="{x(a):.1f}" y="{BASE}" width="{(a - b) * M:.1f}" height="{y(SKIRT) - BASE:.1f}" fill="#4b5158"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{BASE}" width="{d.SECOND_END - d.VB_X + 10 - 50:.1f}" height="{y(SKIRT) - BASE:.1f}" fill="#4b5158"/>')
for c in (23.7, 4.91):
    bogie(c)

# Second car (BFR 73), front end only: body and its window band (B).
S = d.SECOND_END
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
d.windows(d.VB_X - 10, S - 0.2 * M, 1, *WIN)
d.end()
d.gangway()

# Cab car. Outline: roof flat to 2.35 m, the measured nose curve, the vertical front face, the nose bottom.
nose_top = [(2.15, 0.04), (1.95, 0.075), (1.65, 0.16), (1.44, 0.22), (1.14, 0.29), (0.94, 0.335), (0.73, 0.40), (0.53, 0.45), (0.23, 0.53), (0.13, 0.57), (0.03, 0.63)]
d.clip(
    'c1',
    f'M{REAR},{BASE} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} H{x(2.35):.1f} '
    + ' '.join(f'L{P(m, f)}' for m, f in nose_top)
    + f' Q{P(0, 0.66)} {P(0, 0.70)} L{P(0, 0.83)} Q{P(0.01, 0.95)} {P(0.12, 1.0)} L{P(0.18, 1.05)} L{P(2.2, 1.0)} Z',
)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 30}" fill="url(#body)"/>')
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(2.35) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# SJ Nord: navy forward of the stripe (and over the roof from the cab seam), the red stripe, the hatched bands.
top, sill = 0.084, 1.0
d.paint(
    f'<path d="M{P(R(top) - 0.30, top)} L{P(4.04, top)} L{P(4.04, -0.1)} L{P(-1, -0.1)} L{P(-1, 1.2)} L{P(R(1.2) - 0.30, 1.2)} Z" fill="url(#navy)"/>',
    SJ,
)
d.paint(f'<path d="M{P(R(top), top)} L{P(R(top) - 0.19, top)} L{P(R(sill) - 0.19, sill)} L{P(R(sill), sill)} Z" fill="url(#sjred)"/>', SJ)
hatch(27.9, 4.1, -0.02, top, 0.33, 0.13, '#c3c6cf', SJ)
dash_from = R(0.81) + 0.12
for a, b in ((27.9, 20.3), (18.5, 8.0), (6.45, dash_from + 0.92)):
    hatch(a, b, 0.70, 0.81, 0.23, 0.09, '#c9ccd4', SJ)
hatch(dash_from + 0.92, dash_from, 0.70, 0.81, 0.23, 0.09, '#e0566b', SJ)
# Cab module seam, windscreen, cab side window (A).
d.add(f'<path d="M{P(4.04, 0)} V{y(0.374):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
d.add(f'<path d="M{P(1.96, 0.10)} L{P(1.08, 0.30)} L{P(1.35, 0.31)} L{P(2.01, 0.21)} Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="2" stroke-linejoin="round"/>')
d.add(
    f'<path d="M{P(2.8, WIN[0])} L{P(2.52, WIN[0])} Q{P(1.95, 0.40)} {P(1.89, 0.46)} L{P(1.91, 0.57)} Q{P(1.95, 0.63)} {P(2.11, 0.645)} '
    f'L{P(2.27, WIN[1])} L{P(2.8, WIN[1])} Z" fill="#0b0d10"/>'
)
d.add(f'<path d="M{P(2.75, WIN[0] + 0.03)} L{P(2.55, WIN[0] + 0.03)} Q{P(2.02, 0.42)} {P(1.97, 0.47)} L{P(1.99, 0.56)} Q{P(2.03, 0.61)} {P(2.17, 0.62)} L{P(2.31, WIN[1] - 0.03)} L{P(2.75, WIN[1] - 0.03)} Z" fill="url(#glass)"/>')
# Windows (B; panes from D) and doors (B).
d.windows(x(4.18), x(2.8), 1, *WIN)
d.windows(x(6.2), x(4.18), 1, *WIN)
d.windows(x(18.55), x(7.96), 4, *WIN)
d.windows(x(25.4), x(20.3), 2, *WIN)
d.add(f'<rect x="{x(27.75):.1f}" y="{y(WIN[0]):.1f}" width="{2.35 * M:.1f}" height="{y(WIN[1]) - y(WIN[0]):.1f}" rx="3" fill="#0b0d10"/>')
d.door(x(7.96), 1.48 * M, *DOOR, win=(0.1, 0.9, 0.27, 0.72))
d.door(x(20.26), 1.71 * M, *DOOR, win=(0.1, 0.9, 0.27, 0.72))
d.add(f'<ellipse cx="{x(0.06):.1f}" cy="{y(0.68):.1f}" rx="3" ry="4.5" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')
d.end()
# Fairing under the nose, with its yellow strip (on every livery's photos: A, and the 2026 Go-Ahead and SJ photos).
d.add(f'<path d="M{P(2.2, 1.0)} L{P(1.6, 1.12)} L{P(1.34, 1.21)} L{P(1.28, 1.27)} L{P(0.2, 1.27)} Q{P(0.1, 1.27)} {P(0.1, 1.22)} L{P(0.12, 1.08)} L{P(0.18, 1.04)} Z" fill="#3b4148"/>')
d.add(f'<path d="M{P(1.28, 1.235)} L{P(0.16, 1.235)} Q{P(0.11, 1.24)} {P(0.12, 1.27)} L{P(1.28, 1.27)} Z" fill="#f2b705"/>')

COMMENT = '// NSB/Norske Tog Type 73 (BM 73 cab car), side view to scale. Generated by scripts/trains/no_type73.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'NoType73.tsx')
if __name__ == '__main__':
    main(d, 'NoType73Side', COMMENT, OUT)
