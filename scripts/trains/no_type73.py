"""NSB/Norske Tog Type 73 Signatur (Adtranz, 4 cars), cab car BFM 73. docs/TRAIN_ART.md; x3.py is the worked example.

The drawn car is the BFM end (family car): every current photo we have of a Type 73 cab end shows it (A, E, F below),
and the BM end has a different door layout (B: one passenger door at 6.48 m, no crew door). Until 2026-10-23 this
script drew the BM layout from B under A's (BFM) nose and stripe; fixed.

Who runs it and in what livery (checked 2026-10-22/23):
- SJ Nord (sets 03, 06, 07, 09, 11, 14; no.wikipedia "Type 73 (motorvognsett)"): navy front, silver body, a red
  diagonal stripe. Seen in service Aug 2026 (Flickr 55485812179, 73 003) and July 2024 (A). Drawn: `sj-nord`. Some
  sets carry temporary wraps (Peer Gynt, Kvitfjell, Pride); those are not the livery.
- Go-Ahead Norge (sets 01, 02, 04, 05, 08, 12, 15, 16): dark navy all over, silver roof, light- and mid-blue diagonal
  stripes on the cab car (E, F; Flickr 55485752348, Aug 2026). Drawn: `go-ahead-norge`, the parts that could be
  measured (see below).
- Vy (the six 73B sets, 41-46): being repainted from NSB red to Vy green and black (jernbane.net: 73-45 green
  2025-04-07, 73-41 "nylakkert i svart og grønt" 2025-05-23, 73-44 and 73-42/43 still red in May 2025). Mid-repaint:
  NOT drawn (shows unpainted).

Sources (retrieved 2026-10-22, owner's photos 2026-10-23):
- A. Side-on photo, SJ Nord BFM 73 111 at Otta, 2024-07-09, Flickr "Kurbelwelle" 53848497575 (1024 px). Nose, cab,
  doors, red stripe, navy edge, roof and waist bands, front bogie. Nose tip x=867 px, roof y=282, sill (bottom of the
  painted body) y=496, rail y=576; 79 px/m (roof to rail 3.70 m, no.wikipedia; front bogie axles 216 px = 2.7 m).
- B. Side-on photo of a whole BM 73 (73 009, old livery), Holten NL 2014-05-11, Flickr "J. Zwoferink" 13974008849,
  30.4 px/m: the car's overall length (27.93 m) and its rear end (dark end panel 25.4-27.7 m). Its door layout is the
  BM's and is not used.
- C. Near side-on 350 px photo, SJ Nord BM 73 014, Oslo S 2023-06-11, jernbane.net image 290733: on the BM end the
  red stripe sits at about the same distance from the nose (its foot ~3.4 m from the tip, +-0.3 m).
- D. Norske Tog car drawing type73-BFM73A.svg (norsketog.no/tog/motorvognsett/type-73-serie-a): checked to scale
  against A at the crew door (4.41 vs 4.42 m) and the first passenger door (8.0-9.6 vs 7.99-9.49 m), so used for the
  rear 18 m that no photo shows: window 9.53-19.55 m, rear passenger door 19.64-21.28 m, window 21.35-25.4 m, rear
  bogie centre 24.2 m. Pane counts there are D's and approximate.
- E. Owner's photo 61 (Go-Ahead 73 008 at a depot, 3/4 from the cab end, 2000 px). Rectified to a side view with a
  homography on the crew door's four corners (4.42/5.61 m, f .243/.963) and the first passenger door's window (7.99/
  9.51 m, f .271/.822) from A; residuals 0.2-3.4 px (<= 0.06 m). Every Go-Ahead stripe below is read off it.
- F. Owner's photo 62 (Go-Ahead set in a valley, 3/4): cross-check of the stripe pattern (same order of light, mid and
  dark bands above and below the windows; too small to measure).
- G. Owner's photo 63 (SJ Nord 73, almost side-on, Trondheim, 1280 px; the door layout is the BFM's): recheck of the
  nose and red stripe. Tip x=252, roof y=121, sill y=474, ~129 px/m: the red stripe's rear edge is at 6.10 m at f .215
  and 3.98 m at f .975 (drawing 6.00 and 3.84), crew door front 4.63 m (drawing 4.42): within 0.1-0.2 m (G is not
  quite square on).
- no.wikipedia Type 73: end cars 27.9 m, wheels 870 mm, height 3.7 m.

Measured (metres from the nose tip; fractions of roof-to-sill height, 2.71 m):
- From A: roof flat to 2.35 m, then (2.15, .04) (1.95, .075) (1.65, .16) (1.44, .22) (1.14, .29) (0.94, .335)
  (0.73, .40) (0.53, .45) (0.23, .53) (0.13, .57) (0.03, .63); front face vertical .63-.83; nose bottom (0.12, 1.0).
  Windscreen (1.96, .10) (1.08, .30) (1.35, .31) (2.01, .21). Cab side window front edge (2.52, .36) (1.89, .46)
  (1.91, .57) (2.11, .645) (2.27, .69). Window band .374-.70; pillars 2.8, 4.06, 6.92 m. Cab module seam 4.04 m.
  Crew door 4.42-5.62 m, f .24-.99, its window 4.49-5.53, .29-.69. Passenger door 7.99-9.49 m, f .26-1.10, window
  .27-.79. Under-nose fairing from the sill at 2.2 m down to 1.27 at 1.28 m; yellow strip 1.235-1.27 from 1.28 to
  0.15 m. Skirt to 1.26. Front bogie axles 3.54 and 6.28 m (centre 4.91); wheel centre 0.435 m above rail, rail 1.373.
  The bogie is the kit's (frame over the upper half of the wheels), at that wheel height.
- Red stripe (sj-nord, A): straight, 45 deg; rear edge R(f) = 4.11 + 2.852 * (0.8785 - f) m (6.38 m at .084, 3.76 m
  at the sill); 0.19 m wide; a 0.11 m silver gap, then navy to the nose; navy over the roof from the cab seam forward.
- Roof-edge band 0-.084 and waist band .70-.81 (sj-nord, A): light grey diagonal hatch, periods 0.33 and 0.23 m; four
  red dashes behind the red stripe in the waist band, on the crew door.
- Go-Ahead (E): silver roof down to f .225 behind the cab seam (the navy cab top meets it at 4.05 m with a round
  corner); navy everywhere else. Stripes, as straight bands in two lighter blues (light ~#8bb6e0, mid ~#3576c2):
  - below the windows (f .70 to the sill), slope 3.28 m per unit f (0.59 m forward per .18 f, the same for all 12
    edges within 0.03 m), edges at f .74: navy | 7.645 mid 6.825 light 6.525 mid 6.315 light 5.45 mid 4.645 navy
    4.315 mid 3.995 light 3.775 mid 2.905 light 2.515 mid 1.77 | navy;
  - above the windows (f .225-.374), slope 2.3 m per unit f, edges at f .27 / .34: 7.97/7.81 light 7.655/7.485 mid
    7.485/7.33 light 6.635/6.485 mid 5.19/5.03 light 4.98/4.81 mid 4.10/3.94 light 3.79/3.63 mid 2.62/2.46.
    The two bands' slopes differ in the rectified photo (2.3 vs 3.28 m per f); that may be the body's curve above the
    windows rather than the paint, which a 3/4 photo can't separate. Positions at each band's middle are good to
    ~0.1 m; the band edges to ~0.15 m.
  - Not drawn: the long stripes over the nose forward of ~2.5 m (above the windows) and ~1.8 m (below). The nose
    curves away from the side there, so the rectified photo can't place them to 0.2 m; a side-on photo of a Go-Ahead
    cab would. The nose stays navy.
- Not drawn: roof antennas (too small), lettering and logos, door colours, the louvres on the skirt.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

SJ, GA = 'sj-nord', 'go-ahead-norge'
d = Drawing(car_m=27.93, body_m=2.71, gangway_m=0.5, liveries=[SJ, GA])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('navy', ['#2c3a5c', '#1f2a44', '#18213a'])
d.gradient('sjred', ['#e4475f', '#d63a52'])
d.gradient('ganavy', ['#26417f', '#1e356a', '#182c59'])
d.gradient('galight', ['#9cc3ea', '#86b2df', '#79a6d6'], stops=(0, 0.5, 1))
d.gradient('gamid', ['#3d82cf', '#3576c2', '#2c69b2'], stops=(0, 0.5, 1))


def P(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


WIN = (0.374, 0.70)
RAIL = 1.373
WHEEL_R = 0.435
SKIRT = 1.26


def R(f):
    """Rear edge of the SJ Nord red stripe, metres from the tip, at height f."""
    return 4.11 + 2.852 * (0.8785 - f)


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


def bands(edges, f0, f1, at, slope, fills, only):
    """Go-Ahead stripes in one horizontal band f0-f1: straight edges, each at `edges[i]` metres at height `at`,
    moving forward `slope` metres per unit f going down; fills[i] colours the region between edges i and i+1."""
    def e(i, f):
        return edges[i] - slope * (f - at)

    for i, fill in enumerate(fills):
        if fill:
            d.paint(f'<path d="M{P(e(i, f0), f0)} L{P(e(i + 1, f0), f0)} L{P(e(i + 1, f1), f1)} L{P(e(i, f1), f1)} Z" fill="url(#{fill})"/>', only)


# Underframe skirt between the bogie openings (A: front opening 7.16-2.2 m; D: rear opening 25.6-22.8 m).
for a, b in ((27.75, 25.6), (22.8, 7.16)):
    d.add(f'<rect x="{x(a):.1f}" y="{BASE}" width="{(a - b) * M:.1f}" height="{y(SKIRT) - BASE:.1f}" fill="#4b5158"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{BASE}" width="{d.SECOND_END - d.VB_X + 10 - 50:.1f}" height="{y(SKIRT) - BASE:.1f}" fill="#4b5158"/>')
for c in (24.2, 4.91):
    d.bogie(x(c), axle_m=2.7, wheel_m=0.87, wc=y(RAIL) - WHEEL_R * M)

# Second car (BFR 73), front end only: body, its window band, the cab car's roof and colours.
S = d.SECOND_END
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
W2 = S - d.VB_X + 10
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{W2}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(0.225):.1f}" width="{W2}" height="{BASE - y(0.225):.1f}" fill="url(#ganavy)"/>', GA)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{W2}" height="5" fill="url(#roof)"/>')
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
for a, b in ((27.9, 21.35), (19.55, 9.53), (7.95, dash_from + 0.92)):
    hatch(a, b, 0.70, 0.81, 0.23, 0.09, '#c9ccd4', SJ)
hatch(dash_from + 0.92, dash_from, 0.70, 0.81, 0.23, 0.09, '#e0566b', SJ)
# Go-Ahead: navy below the silver roof (and over the cab top from 4.05 m), then the measured stripes (E).
d.paint(
    f'<path d="M{P(28.5, 0.225)} L{P(4.25, 0.225)} Q{P(4.05, 0.225)} {P(4.05, 0.12)} L{P(4.05, -0.1)} L{P(-1, -0.1)} L{P(-1, 1.3)} L{P(28.5, 1.3)} Z" fill="url(#ganavy)"/>',
    GA,
)
bands([7.645, 6.825, 6.525, 6.315, 5.45, 4.645, 4.315, 3.995, 3.775, 2.905, 2.515, 1.77], 0.70, 1.0, 0.74, 3.28,
      ['gamid', 'galight', 'gamid', 'galight', 'gamid', None, 'gamid', 'galight', 'gamid', 'galight', 'gamid'], GA)
up27 = [7.97, 7.655, 7.485, 6.635, 5.19, 4.98, 4.10, 3.79, 2.62]
up34 = [7.81, 7.485, 7.33, 6.485, 5.03, 4.81, 3.94, 3.63, 2.46]
slope_up = sum(a - b for a, b in zip(up27, up34)) / len(up27) / 0.07
bands([(a + b) / 2 for a, b in zip(up27, up34)], 0.225, WIN[0], 0.305, slope_up, ['galight', 'gamid', 'galight', 'gamid', 'galight', 'gamid', 'galight', 'gamid'], GA)
# Cab module seam, windscreen, cab side window (A).
d.add(f'<path d="M{P(4.04, 0)} V{y(0.374):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
d.add(f'<path d="M{P(1.96, 0.10)} L{P(1.08, 0.30)} L{P(1.35, 0.31)} L{P(2.01, 0.21)} Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="2" stroke-linejoin="round"/>')
d.add(
    f'<path d="M{P(2.8, WIN[0])} L{P(2.52, WIN[0])} Q{P(1.95, 0.40)} {P(1.89, 0.46)} L{P(1.91, 0.57)} Q{P(1.95, 0.63)} {P(2.11, 0.645)} '
    f'L{P(2.27, WIN[1])} L{P(2.8, WIN[1])} Z" fill="#0b0d10"/>'
)
d.add(f'<path d="M{P(2.75, WIN[0] + 0.03)} L{P(2.55, WIN[0] + 0.03)} Q{P(2.02, 0.42)} {P(1.97, 0.47)} L{P(1.99, 0.56)} Q{P(2.03, 0.61)} {P(2.17, 0.62)} L{P(2.31, WIN[1] - 0.03)} L{P(2.75, WIN[1] - 0.03)} Z" fill="url(#glass)"/>')
# Windows (A; behind the first passenger door, D) and doors (A; the rear passenger door, D).
d.windows(x(4.06), x(2.8), 1, *WIN)
d.windows(x(4.40), x(4.08), 1, *WIN)
d.windows(x(6.90), x(5.66), 2, *WIN)
d.windows(x(7.97), x(6.94), 1, *WIN)
d.windows(x(19.55), x(9.53), 4, *WIN)
d.windows(x(25.4), x(21.35), 2, *WIN)
d.add(f'<rect x="{x(27.75):.1f}" y="{y(WIN[0]):.1f}" width="{2.35 * M:.1f}" height="{y(WIN[1]) - y(WIN[0]):.1f}" rx="3" fill="#0b0d10"/>')
d.door(x(5.62), 1.20 * M, 0.24, 0.99, win=(0.06, 0.94, 0.29, 0.69))
d.door(x(9.49), 1.50 * M, 0.26, 1.10, win=(0.03, 0.97, 0.27, 0.79))
d.door(x(21.28), 1.64 * M, 0.26, 1.10, win=(0.03, 0.97, 0.27, 0.79))
d.add(f'<ellipse cx="{x(0.06):.1f}" cy="{y(0.68):.1f}" rx="3" ry="4.5" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')
d.end()
# Fairing under the nose, with its yellow strip (A, E, G).
d.add(f'<path d="M{P(2.2, 1.0)} L{P(1.6, 1.12)} L{P(1.34, 1.21)} L{P(1.28, 1.27)} L{P(0.2, 1.27)} Q{P(0.1, 1.27)} {P(0.1, 1.22)} L{P(0.12, 1.08)} L{P(0.18, 1.04)} Z" fill="#3b4148"/>')
d.add(f'<path d="M{P(1.28, 1.235)} L{P(0.16, 1.235)} Q{P(0.11, 1.24)} {P(0.12, 1.27)} L{P(1.28, 1.27)} Z" fill="#f2b705"/>')

COMMENT = '// NSB/Norske Tog Type 73 (BFM 73 cab car), side view to scale. Generated by scripts/trains/no_type73.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'NoType73.tsx')
if __name__ == '__main__':
    main(d, 'NoType73Side', COMMENT, OUT)
