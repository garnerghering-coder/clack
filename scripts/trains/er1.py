"""Mälartåg ER1 (Stadler DOSTO/KISS, 4 cars, double-deck), cab car. docs/TRAIN_ART.md; style as x3.py.

Sources (all retrieved 2026-10-22):
- Stadler reference sheet "DOSTO Tåg i Bergslagen, AB Transitio" (DOSTO_TIB0522e),
  https://a.storyblok.com/f/269997/x/5408827293/kiss_ab-transitio_en.pdf (linked from
  https://www.stadlerrail.com/en/solutions/references/kiss-ab-transitio). Page 2 has the manufacturer's to-scale side
  elevation of the 4-car ER1, rendered at 1200 dpi: 83.64 px/m (104.81 m over couplers = 8766 px; vehicle height
  4.70 m checks at 4.69 m). The ER1 bodies are the same for Mälartåg and Tåg i Bergslagen; the end cars are mirror
  images, so the right-hand cab car is drawn as is. Data: wheel 0.92 m, bogie wheelbase 2.5 m, door width 1.3 m.
- järnväg.net ER1 page https://www.jarnvag.net/vagnguide/er1 : photos extER1_024_Orebro211026stor.jpg (Mälartåg,
  3/4) and extER1_007_Katrineholm211027.jpg (3/4) for the livery; line-guide photos (Nyköping 2024) for colours.
- Mälartåg's own car graphic ER1_avdelningar2025.png (same page): blue upper band, white lower body, red door frames.
Measured off the Stadler elevation (cab car; metres back from the body nose; fractions of body height, roof y=66 px to
the body underside over the bogies y=392 px = 3.90 m; rail at 457.5 px):
- coupler face 0.61 m ahead of the body nose (drawn; it is the train's front in side view); car 26.10 m body nose to
  rear end, gangway bellows 0.75 m; bogies 4.79 m and 23.27 m, axles 2.5 m (sheet; rear bogie hubs measure 2.49 m)
- lower deck between the bogies drops to 1.150 (0.23 m above rail) from 7.08 m to 20.99 m, 45-degree ramps up to
  the ends (6.56 m, 21.57 m)
- passenger doors 7.93–9.61 m and 18.42–20.09 m, 0.465–1.060; door windows 0.572–0.857, 0.34–0.66 of the door width
- lower-deck windows 4 x 1.53 m from 10.11 to 17.92 m (pitch 2.09 m), 0.701–0.891; upper deck at the same x,
  0.179–0.351, plus narrow upper windows over each door (8.45–9.09 m, 18.93–19.58 m)
- mid-level window behind the cab 4.23–5.76 m, 0.459–0.646; small square window 3.35–3.70 m, 0.474–0.563;
  at the rear end a window 21.78–22.34 m (0.459–0.646) and a dark window 24.13–25.02 m (0.472–0.825)
- door-side displays 7.15–7.59 m and 20.43–20.88 m, 0.721–0.810; destination display 12.53–13.40 m, 0.589–0.672;
  drip strip over the doors at 0.416
- cab door 2.25–2.81 m, 0.368–0.847, its window 0.417–0.601 (0.26–0.74 of the door width)
- nose silhouette scanned row by row (every 12 px): roof drops to 0.018 at 4.83 m, 0.058 at 2.56 m, then (2.03, 0.092)
  (1.53, 0.166) (1.23, 0.239) (0.99, 0.313) (0.78, 0.387) (0.59, 0.460) (0.42, 0.534) (0.19, 0.589) (0.06, 0.663) to the
  tip at 0–0.81; windscreen band between the A-pillar (2.56, 0.058)–(2.14, 0.288)
  and the curve (2.14, 0.282) (1.00, 0.380) (0.53, 0.509) (0.11, 0.718); headlight 0.11–0.47 m, 0.724–0.816;
  plough to 1.153 from 1.24 m to the tip; roof grilles 4.88–5.99 m (0.129–0.255) and 22.25–24.94 m
Livery (Mälartåg), from the Örebro photo rectified to side-on with 16 control points on the window corners (rms 2.4 cm):
- blue from the roof down to a straight edge 3.06 m above rail (0.416, the drip strip) along the whole car;
- at the cab the blue comes down: straight edge from (4.12 m, 0.416) to (3.24 m, 0.819) [1.49 m above rail], then
  level to the nose; both knees rounded ~0.12 m. White below.
- red frame round each passenger door, 0.135 m wide at the sides and top, down to 0.70 m above rail (1.021).
Not drawn: cab handrails (the drawing and photos disagree on their length), roof pantograph (car not confirmed).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

MT = 'malartag'
C = 0.61  # coupler face ahead of the body nose
d = Drawing(car_m=C + 26.10, body_m=3.90, show_second_m=1.6, gangway_m=0.75, liveries=[MT])
y, M, ROOF, BASE, TIP, REAR = d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
S = d.SECOND_END
d.gradient('mtblue', ['#2a6cf2', '#0a55e2', '#0546c6'], stops=(0, 0.55, 1))
RED = '#e04b47'


def x(m):
    """Metres back from the body nose."""
    return d.x(C + m)


def pt(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


BAND = 0.416
LOW = 1.150
UP = (0.179, 0.351)
LOWWIN = (0.701, 0.891)


def door(m_front, m_rear, only_frame=True):
    x0, x1 = x(m_rear), x(m_front)
    w = x1 - x0
    d.door(x0, w, 0.465, 1.060, win=(0.34, 0.66, 0.572, 0.857))
    # Red frame: 0.135 m outside the door at the sides and top, down to 0.70 m above rail.
    o = 0.135 * M
    top, bot = y(0.465) - 0.13 * M, y(1.021)
    r = 0.15 * M
    d.paint(
        f'<path fill-rule="evenodd" fill="{RED}" d="M{x0 - o:.1f},{bot:.1f} V{top + r:.1f} Q{x0 - o:.1f},{top:.1f} {x0 - o + r:.1f},{top:.1f} '
        f'H{x1 + o - r:.1f} Q{x1 + o:.1f},{top:.1f} {x1 + o:.1f},{top + r:.1f} V{bot:.1f} Z '
        f'M{x0:.1f},{bot + 2:.1f} V{y(0.465) + 3:.1f} Q{x0:.1f},{y(0.465):.1f} {x0 + 3:.1f},{y(0.465):.1f} H{x1 - 3:.1f} Q{x1:.1f},{y(0.465):.1f} {x1:.1f},{y(0.465) + 3:.1f} V{bot + 2:.1f} Z"/>',
        MT,
    )


def display(m_front, m_rear):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{y(0.721):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{y(0.810) - y(0.721):.1f}" rx="2" fill="#1d2228"/>')


def grille(m_front, m_rear, top, bottom):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{y(top):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{y(bottom) - y(top):.1f}" rx="1.5" fill="#3a4048" opacity="0.85"/>')


# ---- Second car (car 12), cab-facing end only ----
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{y(BAND) - ROOF:.1f}" fill="url(#mtblue)"/>', MT)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
# Its mid-level window 0.64–1.88 m from its end (0.459–0.646) and a small window 0.22–0.58 m (0.787–0.863).
d.windows(S - 1.883 * M, S - 0.640 * M, 1, 0.459, 0.646)
d.add(f'<rect x="{S - 0.58 * M:.1f}" y="{y(0.787):.1f}" width="{0.36 * M:.1f}" height="{y(0.863) - y(0.787):.1f}" rx="2" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
d.end()
d.gangway()

# ---- Cab car ----
NOSE = [(2.56, 0.058), (2.03, 0.092), (1.73, 0.129), (1.53, 0.166), (1.37, 0.202), (1.23, 0.239), (1.11, 0.276), (0.99, 0.313), (0.87, 0.350),
        (0.78, 0.387), (0.68, 0.423), (0.59, 0.460), (0.50, 0.497), (0.42, 0.534), (0.31, 0.571), (0.19, 0.589), (0.12, 0.626), (0.06, 0.663),
        (0.02, 0.699), (0.0, 0.736)]


def smooth(points):
    """A Catmull-Rom curve through the measured points, as cubic Beziers."""
    p = [(x(m), y(f)) for m, f in points]
    out = []
    for i in range(len(p) - 1):
        p0, p1, p2, p3 = p[max(i - 1, 0)], p[i], p[i + 1], p[min(i + 2, len(p) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return ' '.join(out)


nose = f'L{pt(4.83, 0.0)} L{pt(4.83, 0.018)} L{pt(2.56, 0.058)} ' + smooth(NOSE) + f' L{pt(0.0, 0.81)} L{pt(0.07, 0.831)} L{pt(0.10, 1.012)} '
body = (
    f'M{REAR},{BASE} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} ' + nose + f'L{pt(1.60, 1.012)} L{pt(1.60, 1.0)} '
    f'L{pt(6.56, 1.0)} L{pt(7.08, LOW)} L{pt(20.99, LOW)} L{pt(21.57, 1.0)} Z'
)
d.clip('c1', body)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{y(LOW) - ROOF + 8:.1f}" fill="url(#body)"/>')
# Mälartåg blue: band to 3.06 m above rail, and the cab block down to 1.49 m (two straight edges, rounded knees).
r = 0.12 * M
kx, ky = x(4.12), y(BAND)
bx, by = x(3.24), y(0.819)
d.paint(
    f'<path d="M{REAR - 2},{ROOF - 4} V{ky:.1f} H{kx - r:.1f} Q{kx:.1f},{ky:.1f} {kx + 0.25 * r:.1f},{ky + 0.45 * r:.1f} '
    f'L{bx - 0.25 * r:.1f},{by - 0.45 * r:.1f} Q{bx:.1f},{by:.1f} {bx + r:.1f},{by:.1f} H{TIP + 10} V{ROOF - 4} Z" fill="url(#mtblue)"/>',
    MT,
)
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(4.83) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# Drip strip over the doors (the blue edge on the Mälartåg car).
for a, b in ((7.0, 10.0), (17.9, 21.9)):
    d.add(f'<line x1="{x(b):.1f}" y1="{y(BAND):.1f}" x2="{x(a):.1f}" y2="{y(BAND):.1f}" stroke="#ffffff" stroke-opacity="0.35" stroke-width="1.2"/>')
# Roof grilles on the end sections.
grille(4.88, 5.99, 0.129, 0.255)
grille(22.25, 24.94, 0.113, 0.248)
# Windscreen band down the nose, and the cab module seam.
d.add(
    f'<path d="M{pt(2.56, 0.058)} L{pt(2.14, 0.288)} C{pt(1.55, 0.300)} {pt(1.0, 0.380)} {pt(0.53, 0.509)} '
    f'Q{pt(0.25, 0.62)} {pt(0.11, 0.718)} L{pt(0.0, 0.736)} ' + smooth(list(reversed(NOSE))) + ' Z" fill="#14181e"/>'
)
d.add(f'<path d="M{pt(2.14, 0.288)} L{pt(1.60, 0.61)} V{y(1.0):.1f}" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
d.add(f'<rect x="{x(0.47):.1f}" y="{y(0.724):.1f}" width="{0.36 * M:.1f}" height="{y(0.816) - y(0.724):.1f}" rx="3" fill="#f3f5f8" stroke="#4b4f55" stroke-width="1"/>')
# Windows.
d.windows(x(5.76), x(4.23), 1, 0.459, 0.646)
d.add(f'<rect x="{x(3.70):.1f}" y="{y(0.474):.1f}" width="{0.35 * M:.1f}" height="{y(0.563) - y(0.474):.1f}" rx="2" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
for i in range(4):
    a = 10.11 + i * 2.087
    d.windows(x(a + 1.53), x(a), 1, *UP)
    d.windows(x(a + 1.53), x(a), 1, *LOWWIN)
for a, b in ((8.45, 9.09), (18.93, 19.58)):
    d.windows(x(b), x(a), 1, *UP)
d.windows(x(22.34), x(21.78), 1, 0.459, 0.646)
d.add(f'<rect x="{x(25.02):.1f}" y="{y(0.472):.1f}" width="{0.89 * M:.1f}" height="{y(0.825) - y(0.472):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
door(7.93, 9.61)
door(18.42, 20.09)
display(7.15, 7.59)
display(20.43, 20.88)
# Destination display between the decks, 12.53–13.40 m, 0.589–0.672.
d.add(f'<rect x="{x(13.40):.1f}" y="{y(0.589):.1f}" width="{0.87 * M:.1f}" height="{y(0.672) - y(0.589):.1f}" rx="3" fill="#1d2228" stroke="#0b0d10" stroke-width="1"/>')
# Cab door.
d.door(x(2.81), 0.56 * M, 0.368, 0.847, win=(0.26, 0.74, 0.417, 0.601))
d.end()

# Underframe: bogies (wheel 0.92 m, axles 2.5 m), plough and coupler.
for c in (x(4.79), x(23.27), S - 2.84 * M):
    d.bogie(c, axle_m=2.5, wheel_m=0.92)
d.add(f'<path d="M{pt(1.24, 1.0)} L{pt(1.24, 1.055)} L{pt(0.77, 1.147)} L{pt(0.05, 1.153)} Q{pt(0.14, 1.10)} {pt(0.10, 1.0)} Z" fill="#3b4148"/>')
d.add(f'<rect x="{x(0.0) - 2:.1f}" y="{y(0.828):.1f}" width="{C * M + 2:.1f}" height="{y(0.988) - y(0.828):.1f}" rx="3" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>')

if __name__ == '__main__':
    main(d)
