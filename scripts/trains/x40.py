"""SJ X40 (Alstom Coradia Duplex, double-deck), cab car, in the renovated SJ livery. docs/TRAIN_ART.md; style as x3.py.

Sources (all retrieved 2026-10-22):
- SJ's side elevation of the renovated X40, "Sidovy av upprustade X40. Bild SJ":
  https://www.jarnvag.net/images/bild/vagnguide/X40_sidovy_upprustad.jpg (4353 x 598, from
  https://www.jarnvag.net/vagnguide/x40). A to-scale orthographic side view of the 3-car set: 81.5 m nose to nose =
  4218 px; the cab car over couplers checks at 27.62 m against 27.55 m, bogie centres at 19.9 m against 20.0 m, wheels
  at 0.93 m against 0.92 m. Scale used: 51.8 px/m. Its right-hand car faces right and is drawn as is.
- järnväg.net X40 page (same URL): length 27.55 m per end car, 81.5 m per 3-car set; "Fronterna, dörrarna och
  områdena mellan fönsterraderna har fått en mörkare färg och dörrarna markeras med grön färg" (renovation 2024–2028).
  Photo extX40_3324_Jonsered251230stor.jpg (renovated, 3/4) for the colours and the dark front's straight edges.
- sv.wikipedia "X40" (action=raw): bogie centres 20 000 mm, drive wheels 920 mm, car body width 2 960 mm.
Measured off the SJ elevation (metres back from the nose tip; fractions of body height, roof y=161 px to the body
underside over the bogies y=351 px = 3.67 m; rail at 394 px):
- car 27.14 m nose to rear end, gangway 0.87 m; bogies 4.50 m and 24.40 m, axles 2.47 m
- lower deck between the bogies drops to 1.153 from 6.31 m to 22.36 m (square corners); rear-end skirt to 1.032
- passenger doors 7.03–8.61 m and 20.23–21.83 m, 0.316–1.079, windows 7.43–7.90 m / 20.91–21.41 m, 0.511–0.774
- double-deck window bay 9.63–18.99 m, 0.116–0.974 (rounded 0.12 m): six openings per deck, glass 9.92–10.48,
  10.85–12.32, 12.68–14.15, 14.50–15.97, 16.33–17.80, 17.80/18.15–18.73 m; upper 0.145–0.374, lower 0.671–0.929
- end window bands 3.94–6.54 m and 22.18–24.96 m, 0.426–0.732, glass 0.453–0.705 (4.09–5.48 + 5.85–6.43 m;
  22.32–22.92 + 23.24–24.75 m); rear-end equipment hatch 25.08–26.97 m, 0.311–0.900
- cab: hatch 2.84–3.53 m (0.350–0.895), cab door 2.08–2.65 m (0.337–0.863) with window 2.14–2.63 m (0.374–0.563),
  headlight 0.52–1.27 m (0.663–0.837), lower lamp 0.46–0.91 m (0.874–0.968)
- nose silhouette scanned row by row (every 10 px): roof level to 3.17 m, then (2.66, 0.047) (1.99, 0.153) (1.60, 0.258)
  (1.25, 0.363) (0.95, 0.468) (0.64, 0.574) (0.39, 0.679) (0.17, 0.784) to the tip at 0.889–0.942; under it (0.08, 1.047)
  (0.54, 1.100) (0.87, 1.153), skirt bottom 1.174 from 0.9 to 1.81 m, back up at 2.07 m
- roof grilles 5.73–6.78 m and 20.83–21.83 m (0.079–0.174), slots 6.89–7.43 m and 20.17–20.71 m (0.121–0.163)
Livery (SJ, renovated), from the same elevation:
- light grey body; dark grey front behind a straight vertical edge at 5.68 m from the roof down to 0.324, then one
  straight line to the body underside at 3.55 m; dark grey window bay (the area between the window rows); dark grey
  doors; green door frames 0.11 m wide at the sides, 0.03 m at the top (0.284), and a green panel beside each door on
  the side away from the car centre (6.56–6.89 m and 21.99–22.20 m, 0.432–0.721).
Second car: its end 0–0.6 m plain, window band from 0.6 m with glass 0.75–2.14 m (0.453–0.705); bogie 2.90 m in.
Not drawn: pantograph (on the middle car, outside this picture), lettering and logos.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

SJ = 'sj'
d = Drawing(car_m=27.14, body_m=3.67, show_second_m=1.6, gangway_m=0.87, liveries=[SJ])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
S = d.SECOND_END
d.gradient('sjgrey', ['#c9ccd0', '#bcc0c5', '#a8adb3'], stops=(0, 0.6, 1))
DARK = '#3a3e44'
BAY = '#1f2227'
GREEN = '#1fae45'


def pt(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


def rect(m_front, m_rear, top, bottom, fill, rx=2, only=None, extra=''):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{y(top):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{y(bottom) - y(top):.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def glass(m_front, m_rear, top, bottom):
    d.add(f'<rect x="{x(m_rear) + 1.5:.1f}" y="{y(top):.1f}" width="{x(m_front) - x(m_rear) - 3:.1f}" height="{y(bottom) - y(top):.1f}" rx="2" fill="url(#glass)"/>')


def band(m_front, m_rear, panes):
    """A black window band with its glass panes (all liveries)."""
    rect(m_front, m_rear, 0.426, 0.732, '#0b0d10', rx=3)
    for a, b in panes:
        glass(a, b, 0.453, 0.705)


# ---- Second car, cab-facing end only ----
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#sjgrey)"/>', SJ)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{y(0.426):.1f}" width="{S - 0.6 * M - d.VB_X + 10:.1f}" height="{y(0.732) - y(0.426):.1f}" rx="3" fill="#0b0d10"/>')
d.add(f'<rect x="{S - 2.14 * M + 1.5:.1f}" y="{y(0.453):.1f}" width="{1.39 * M - 3:.1f}" height="{y(0.705) - y(0.453):.1f}" rx="2" fill="url(#glass)"/>')
d.end()
d.gangway()

# ---- Cab car ----
NOSE = [(3.17, 0.0), (2.66, 0.047), (2.28, 0.100), (1.99, 0.153), (1.80, 0.205), (1.60, 0.258), (1.43, 0.311), (1.25, 0.363), (1.10, 0.416),
        (0.95, 0.468), (0.79, 0.521), (0.64, 0.574), (0.50, 0.626), (0.39, 0.679), (0.25, 0.732), (0.17, 0.784), (0.08, 0.837), (0.0, 0.889),
        (0.0, 0.942), (0.06, 0.995), (0.08, 1.047), (0.54, 1.100), (0.87, 1.153)]


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


body = (
    f'M{REAR},{y(1.032):.1f} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} L{pt(3.17, 0.0)} ' + smooth(NOSE) + ' '
    f'L{pt(1.81, 1.174)} L{pt(2.03, 1.111)} L{pt(2.07, 1.0)} '
    f'L{pt(6.31, 1.0)} L{pt(6.31, 1.153)} L{pt(22.36, 1.153)} L{pt(22.36, 1.0)} L{pt(26.43, 1.0)} L{pt(26.43, 1.032)} Z'
)
d.clip('c1', body)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{y(1.2) - ROOF + 4:.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{y(1.2) - ROOF + 4:.1f}" fill="url(#sjgrey)"/>', SJ)
# Dark front: vertical edge at 5.68 m to 0.324, then straight to the underside at 3.55 m.
d.paint(f'<path d="M{x(5.68):.1f},{ROOF - 4} V{y(0.324):.1f} L{x(3.55):.1f},{y(1.0):.1f} L{x(2.07):.1f},{y(1.3):.1f} H{TIP + 10} V{ROOF - 4} Z" fill="{DARK}"/>', SJ)
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(3.17) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# Roof grilles and slots.
rect(5.73, 6.78, 0.079, 0.174, '#2c3137', rx=1)
rect(20.83, 21.83, 0.079, 0.174, '#2c3137', rx=1)
rect(6.89, 7.43, 0.121, 0.163, '#14181e', rx=1)
rect(20.17, 20.71, 0.121, 0.163, '#14181e', rx=1)
# Double-deck window bay: dark grey in the SJ livery; the openings are framed in every livery.
rect(9.63, 18.99, 0.116, 0.974, BAY, rx=5, only=SJ)
for a, b in ((9.92, 10.48), (10.85, 12.32), (12.68, 14.15), (14.50, 15.97), (16.33, 17.80), (18.15, 18.73)):
    for top, bottom in ((0.145, 0.374), (0.671, 0.929)):
        d.windows(x(b) - 2, x(a) + 2, 1, top, bottom)
# End window bands.
band(3.94, 6.54, ((4.09, 5.48), (5.85, 6.43)))
band(22.18, 24.96, ((22.32, 22.92), (23.24, 24.75)))
# Rear-end equipment hatch.
d.add(f'<rect x="{x(26.97):.1f}" y="{y(0.311):.1f}" width="{x(25.08) - x(26.97):.1f}" height="{y(0.900) - y(0.311):.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
# Doors.
for front, rear, info_front in ((7.03, 8.61, True), (20.23, 21.83, False)):
    x0, x1 = x(rear), x(front)
    rect(front, rear, 0.316, 1.079, DARK, rx=3, only=SJ)
    d.door(x0, x1 - x0, 0.316, 1.079, win=(0.452, 0.753, 0.511, 0.774) if info_front else (0.263, 0.575, 0.511, 0.774))
    o, top, bot = 0.115 * M, y(0.284), y(1.079)
    d.paint(
        f'<path fill-rule="evenodd" fill="{GREEN}" d="M{x0 - o:.1f},{bot:.1f} V{top + 3:.1f} Q{x0 - o:.1f},{top:.1f} {x0 - o + 3:.1f},{top:.1f} '
        f'H{x1 + o - 3:.1f} Q{x1 + o:.1f},{top:.1f} {x1 + o:.1f},{top + 3:.1f} V{bot:.1f} Z M{x0:.1f},{bot + 1:.1f} V{y(0.316):.1f} H{x1:.1f} V{bot + 1:.1f} Z"/>',
        SJ,
    )
    if info_front:
        rect(6.56, 6.89, 0.432, 0.721, GREEN, rx=1.5, only=SJ)
    else:
        rect(21.99, 22.20, 0.432, 0.721, GREEN, rx=1.5, only=SJ)
# Cab: hatch, cab door with its window, headlight and lower lamp.
d.add(f'<rect x="{x(3.53):.1f}" y="{y(0.350):.1f}" width="{x(2.84) - x(3.53):.1f}" height="{y(0.895) - y(0.350):.1f}" rx="2" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
d.door(x(2.65), x(2.08) - x(2.65), 0.337, 0.863, win=(0.035, 0.895, 0.374, 0.563))
d.add(f'<rect x="{x(1.27):.1f}" y="{y(0.663):.1f}" width="{x(0.52) - x(1.27):.1f}" height="{y(0.837) - y(0.663):.1f}" rx="5" fill="#f3f5f8" stroke="#4b4f55" stroke-width="1"/>')
d.add(f'<rect x="{x(0.91):.1f}" y="{y(0.874):.1f}" width="{x(0.46) - x(0.91):.1f}" height="{y(0.968) - y(0.874):.1f}" rx="3" fill="#dfe3e8" stroke="#4b4f55" stroke-width="1"/>')
d.end()

# Bogies: wheels 0.92 m, axles 2.47 m.
for c in (x(4.50), x(24.40), S - 2.90 * M):
    d.bogie(c, axle_m=2.47, wheel_m=0.92)

COMMENT = '// SJ X40 (Alstom Coradia Duplex), side view to scale. Generated by scripts/trains/x40.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'X40.tsx')
if __name__ == '__main__':
    main(d, 'X40Side', COMMENT, OUT)
