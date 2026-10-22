"""SJ X2000 (X2), power car leading plus the end of the first coach. docs/TRAIN_ART.md; style as x3.py.

Unpainted only: the current (rebuilt X2C) SJ livery is NOT drawn, see the end of this docstring.

Sources (all retrieved 2026-10-22):
- järnväg.net line guide photo https://www.jarnvag.net/images/bild/banguide/EM720.jpg (Töreboda, August 2007, Markus
  Tellerup), from https://www.jarnvag.net/banguide/ . The only near side-on photo of an X2 power car found. The train
  is seen slightly obliquely, so it was rectified: along the train, a 1-D projective fit to three known points (nose
  tip, power car end at 17.40 m, first coach end at 42.35 m; järnväg.net lengths) gives the horizontal scale; across,
  the heights were fixed from the X2C photo below (the rail is hidden behind a fence in this one). Rectified at
  100 px/m along the train and 114.8 px/m vertically; residuals at the control points under 1 cm.
- järnväg.net X2 page https://www.jarnvag.net/vagnguide/x2 : power car 17 397 mm, coaches 24 950 mm; photo
  extX2_2030_Herrljunga240903.jpg (rebuilt X2C 2030, 3/4) for the heights along one vertical at the front end of the
  corrugated panel (roof, corrugation top and bottom, sill, rail) and the underframe; the rebuild kept the body.
- en.wikipedia "X 2000" (action=raw): height 3.814 m, power car body 16.98 m, bogie centres 8.975 m, axles 2.9 m,
  wheels 1.10 m (power car).
Measured (metres back from the nose tip; fractions of the body height, roof 3.81 m above rail to the sill 1.08 m):
- body 16.98 m; first coach 0.29 m behind (close-coupled bellows); bogie centres 4.00 m and 12.98 m (symmetric, checked
  at 4.5 m and 13.0 m on the X2C photo's underframe)
- corrugated stainless side panel 5.95–15.75 m, 0.163–0.904 (ribs every 0.078 m); smooth band below it to the sill
- crew door 5.13–5.88 m, 0.188–0.900, its latch 5.25–5.45 m, 0.725–0.818; rear door 15.85–16.88 m, 0.227–0.900,
  latch 16.65–16.82 m, 0.722–0.802; body joint ahead of the crew door at 5.05 m
- cab side window 3.55–4.22 m, 0.204–0.435; windscreen seen from the side: (3.00, 0.204) (2.25, 0.220) (1.05, 0.470)
  (2.00, 0.425); headlight at 1.30 m, 0.770
- nose silhouette (row by row): roof level to 3.25 m, then (3.02, 0.003) (2.86, 0.035) (2.60, 0.067) (2.38, 0.099)
  (2.13, 0.131) (1.93, 0.163) (1.80, 0.195) (1.00, 0.489) (0.50, 0.626) (0.10, 0.770) (0.0, 0.866) (0.0, 0.962)
  (0.10, 0.994)
- first coach: tail-lamp window 0.41–0.91 m behind its end, 0.387–0.604
- underframe equipment box between the bogies 6.5–10.7 m (X2C photo)
Not measured, kept simple: the nose fairing below the sill (hidden by the fence; drawn as a plain dark fairing),
pantographs (on the power car, not drawn in any of our pictures), the roof-edge hatches.

Livery: the rebuilt X2C power car has a dark grey front whose edge sweeps from the roof just ahead of the cab window
down to the lower nose, a curve over the 3-D nose that only 3/4 photos show (SJ press photo "Nya_X2000_tag.jpg",
X2C 2030 Herrljunga). No side-on source shows it, so it is not drawn and SJ trains get the unpainted picture, which is
also how the not-yet-rebuilt X2s look (bare stainless with grey ends).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

d = Drawing(car_m=16.98, body_m=2.73, show_second_m=1.6, gangway_m=0.29, liveries=[])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
S = d.SECOND_END


def pt(m, f):
    return f'{x(m):.1f},{y(f):.1f}'


NOSE = [(3.25, 0.0), (3.02, 0.003), (2.86, 0.035), (2.60, 0.067), (2.38, 0.099), (2.13, 0.131), (1.93, 0.163), (1.80, 0.195), (1.40, 0.342),
        (1.00, 0.489), (0.50, 0.626), (0.10, 0.770), (0.0, 0.866), (0.0, 0.962), (0.10, 0.994)]


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


def outline(m_front, m_rear, top, bottom, rx=3):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{y(top):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{y(bottom) - y(top):.1f}" rx="{rx}" fill="none" stroke="#8d949c" stroke-width="1.6"/>')


def latch(m_front, m_rear, top, bottom):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{y(top):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{y(bottom) - y(top):.1f}" rx="1.5" fill="#1d2228"/>')


# ---- First coach, its end only ----
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 4} Q{S},{ROOF} {S},{ROOF + 4} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="5" fill="url(#roof)"/>')
d.windows(S - 0.91 * M, S - 0.41 * M, 1, 0.387, 0.604)
d.end()
d.gangway()

# ---- Power car ----
body = f'M{REAR},{BASE} V{ROOF + 4} Q{REAR},{ROOF} {REAR + 4},{ROOF} L{pt(3.25, 0.0)} ' + smooth(NOSE) + f' L{pt(0.10, 1.0)} Z'
d.clip('c1', body)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 8}" fill="url(#body)"/>')
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(3.25) - REAR:.1f}" height="5" fill="url(#roof)"/>')
# Corrugated stainless panel: a slightly cooler field with its ribs.
x0, x1 = x(15.75), x(5.95)
d.add(f'<rect x="{x0:.1f}" y="{y(0.163):.1f}" width="{x1 - x0:.1f}" height="{y(0.904) - y(0.163):.1f}" fill="#c9ced4" opacity="0.45"/>')
rib = 0.078 * M
n = int((y(0.904) - y(0.163)) / rib)
for i in range(1, n + 1):
    yy = y(0.163) + i * rib
    d.add(f'<line x1="{x0:.1f}" y1="{yy:.1f}" x2="{x1:.1f}" y2="{yy:.1f}" stroke="#7d858e" stroke-opacity="0.28" stroke-width="0.9"/>')
d.add(f'<rect x="{x0:.1f}" y="{y(0.163):.1f}" width="{x1 - x0:.1f}" height="{y(0.904) - y(0.163):.1f}" rx="2" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
# Doors and the body joint in front of the crew door.
outline(5.13, 5.88, 0.188, 0.900)
latch(5.25, 5.45, 0.725, 0.818)
outline(15.85, 16.88, 0.227, 0.900)
latch(16.65, 16.82, 0.722, 0.802)
d.add(f'<path d="M{x(5.05):.1f},{y(0.06):.1f} V{y(1.0):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
# Cab side window, windscreen and headlight.
d.windows(x(4.22), x(3.55), 1, 0.204, 0.435)
d.add(f'<path d="M{pt(3.00, 0.204)} L{pt(2.25, 0.220)} L{pt(1.05, 0.470)} L{pt(2.00, 0.425)} Z" fill="url(#glass)" stroke="#0b0d10" stroke-width="2.4" stroke-linejoin="round"/>')
d.add(f'<ellipse cx="{x(1.30):.1f}" cy="{y(0.770):.1f}" rx="5" ry="3.5" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')
d.end()

# Underframe: equipment box, bogies (axles 2.9 m, wheels 1.10 m), plain fairing under the nose.
d.add(f'<rect x="{x(10.7):.1f}" y="{BASE}" width="{x(6.5) - x(10.7):.1f}" height="9" rx="2" fill="#4b5158"/>')
for c in (x(4.00), x(12.98)):
    d.bogie(c, axle_m=2.9, wheel_m=1.10)
d.add(f'<path d="M{x(2.4):.1f},{BASE} H{x(0.10):.1f} Q{TIP - 2},{BASE} {TIP - 8},{BASE + 8} L{x(0.6):.1f},{BASE + 12} H{x(2.4):.1f} Z" fill="#3b4148"/>')

COMMENT = '// SJ X2000 (X2 power car), side view to scale. Generated by scripts/trains/x2000.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'X2000.tsx')
if __name__ == '__main__':
    main(d, 'X2000Side', COMMENT, OUT)
