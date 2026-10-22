"""Bombardier Contessa X31K / ET (Öresundståg), cab car. docs/TRAIN_ART.md; style as x3.py.

Sources (all retrieved 2026-10-22):
- Öresundståg, oresundstag.se/om-oresundstag (photo "vaxjo1.jpg", datocms-assets 56794/1698334048, file dated
  2023-10, still on the live site): an X31 cab car on the bridge in Växjö, nearly side-on, in the current livery.
  The main measuring photo.
- järnväg.net: ET 4400 Halmstad 2024-08-26 (vagnguide/extET_4400_Halmstad240826.jpg) and ET 4314 Lund 2019-08-02
  (vagnguide/extET_4314Lund190802stor.jpg), 3/4 views in the current livery, used through a perspective fit for the
  rear half and the bogies; banguide/160925_3362.jpg (Örsjö 2016, far side-on) for the car's length; vagnguide
  /x31k page (refurbishment 2018–2023: dark grey and orange at and by the doors; floor plan X31Kstor.gif).
- Skånetrafiken/Öresundståg exterior design drawing of the refurbished middle car (Railcolor News 2018-03-10,
  "Modernising the Øresundtåg ET/X31K"): cross-section heights (window band) and the car's end, at 63.2 px/m
  (from its axle spacing 2.6 m and the floor plan's car proportions; the two agree within 2%).
- sv.wikipedia X31 and de.wikipedia SJ X31K (action=raw): 78.9 m set, motor bogie axles 2600 mm, wheels 830 mm.
- Operator: VR Sverige runs Öresundståg since 2025-12-14 (oresundstag.se, VR press 2024-10-15). The livery belongs
  to Öresundståg (the regions) and no repaint is reported; järnväg.net photos 2024–2026 and the live
  oresundstag.se show this livery. It is the current one.
Measuring (Växjö photo, 1203x756): the window band's top and bottom edges are straight lines that meet at the
vanishing point u=8394 px (top y=0.02437u+457.26, bottom y=0.01679u+520.89, rms 0.3 px). Along the side,
X(u) = C(1/(8394-u) - 1/(8394-u_tip)) with C=896150 set by the door's width, 1.80 m (design drawing); the windows
then come out at 1.459 and 1.431 m, against 1.45 m in the drawing. Heights: the band is 0.882 m tall and its top
0.989 m below the roof (design drawing); body side 2.77 m (body underside seen through the bridge railing).
Measured (metres back from the nose tip; f = fraction of body height down from the roof):
- rubber nose 0–0.44 m; side window band f 0.357–0.675
- windows: 2.58–4.03, 4.42–5.85, 6.26–7.08 | door | 10.45–11.28, then (Lund perspective fit) 11.93–13.37,
  13.79–15.08, 15.60–16.98, 17.52–18.80, 19.41–20.71, 21.41–22.73, 23.27–24.91; pillars between are body colour
- door 7.85–9.65 m, leaves from f 0.182 down, split 8.78; panes 8.06–8.63 and 8.92–9.48, f 0.296–0.669
- paint: dark grey door zone 7.85–9.65 roof to underside; dark grey panels in the band 7.08–7.85 and 9.65–10.45;
  two orange stripes 8.66–8.75 and 8.81–8.89 the full height; destination display 8.07–9.47, f 0.055–0.134
- cab door: window 0.99–1.75, f 0.198–0.491, dark grey panel below it f 0.520–0.669, rain strip above at f 0.166
- roof hatches 6.24–7.08 and 4.46–5.85, f 0.04–0.15 (seen on the roof shoulder)
- car body ends 25.3 m (Örsjö side-on 25.2–25.4, Lund fit 25.2); gangway 0.6 m (two 0.31 m bellows)
- bogies (3/4 photos only, ±0.3 m): front centre 2.1 m (axles 0.8 and 3.4), rear centre 21.9 m; wheel centre f 1.155
Not drawn: lettering and logos; the pantograph (on the middle car). The lower front under the rubber nose is kept
simple (no side-on source shows it).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

OT = 'oresundstag'
d = Drawing(car_m=25.3, body_m=2.77, gangway_m=0.6, liveries=[OT])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('silver', ['#f3f4f6', '#e4e6e9', '#c8ccd1'])
DOORGREY, PANEL, ORANGE = '#4b4a4c', '#66676f', '#f3812f'
BAND = (0.357, 0.675)


def win(m0, m1):
    d.windows(x(m0), x(m1), 1, BAND[0] + 0.012, BAND[1] - 0.012)


def bogie(cm, axle_m=2.6, wheel_m=0.83, wheel_f=1.155):
    cx, s, r = x(cm), axle_m * M / 2, wheel_m * M / 2
    wy = y(wheel_f)
    d.add(f'<rect x="{cx - s - 14:.1f}" y="{BASE + 3}" width="{2 * s + 28:.1f}" height="11" rx="3" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>')
    for k in (-s, s):
        d.add(f'<circle cx="{cx + k:.1f}" cy="{wy:.1f}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
        d.add(f'<circle cx="{cx + k:.1f}" cy="{wy:.1f}" r="5" fill="#6d7681"/>')
    d.add(f'<line x1="{cx - 12:.1f}" y1="{BASE + 9}" x2="{cx + 12:.1f}" y2="{BASE + 6}" stroke="#6d7681" stroke-width="2.4" stroke-linecap="round"/>')


# ---- Second car: the middle car's end (design drawing: window from 0.67 m to 2.1 m from its end). ----
S = d.SECOND_END
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 5} Q{S},{ROOF} {S},{ROOF + 5} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#silver)"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="4" fill="url(#roof)"/>')
d.windows(S - 2.1 * M, S - 0.67 * M, 1, BAND[0] + 0.012, BAND[1] - 0.012)
d.end()
d.gangway()

# ---- Cab car. ----
d.clip(
    'c1',
    f'M{REAR},{BASE} V{ROOF + 5} Q{REAR},{ROOF} {REAR + 5},{ROOF} H{x(0.44):.1f} '
    f'C{x(0.30):.1f},{y(0.004):.1f} {x(0.12):.1f},{y(0.06):.1f} {x(0.05):.1f},{y(0.20):.1f} '
    f'C{x(0.0):.1f},{y(0.30):.1f} {TIP},{y(0.38):.1f} {TIP},{y(0.46):.1f} V{y(0.80):.1f} '
    f'C{TIP},{y(0.88):.1f} {x(0.06):.1f},{y(0.94):.1f} {x(0.18):.1f},{y(0.95):.1f} L{x(0.44):.1f},{y(0.95):.1f} V{BASE} Z',
)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 8}" fill="url(#silver)"/>')
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(0.44) - REAR:.1f}" height="4" fill="url(#roof)"/>')
# Paint: dark grey door zone, the band panels beside it, the orange stripes, the cab door's lower panel.
d.paint(f'<rect x="{x(9.648):.1f}" y="{ROOF - 2}" width="{x(7.848) - x(9.648):.1f}" height="{BASE - ROOF + 2}" rx="4" fill="{DOORGREY}"/>', OT)
for a, b in ((10.45, 9.648), (7.848, 7.082)):
    d.paint(f'<rect x="{x(a):.1f}" y="{y(BAND[0]):.1f}" width="{x(b) - x(a):.1f}" height="{y(BAND[1]) - y(BAND[0]):.1f}" fill="{PANEL}"/>', OT)
d.paint(f'<rect x="{x(1.75):.1f}" y="{y(0.520):.1f}" width="{x(0.99) - x(1.75):.1f}" height="{y(0.669) - y(0.520):.1f}" rx="3" fill="{PANEL}"/>', OT)
# Destination display above the door (equipment, every version).
d.add(f'<rect x="{x(9.47):.1f}" y="{y(0.055):.1f}" width="{x(8.07) - x(9.47):.1f}" height="{y(0.134) - y(0.055):.1f}" rx="1.5" fill="#14181e"/>')
for a, b in ((8.894, 8.805), (8.746, 8.657)):
    d.paint(f'<rect x="{x(a):.1f}" y="{ROOF - 2}" width="{x(b) - x(a):.1f}" height="{BASE - ROOF + 2}" fill="{ORANGE}"/>', OT)
# Roof hatches on the shoulder.
for a, b in ((7.08, 6.24), (5.85, 4.46)):
    d.add(f'<rect x="{x(a):.1f}" y="{y(0.04):.1f}" width="{x(b) - x(a):.1f}" height="{y(0.15) - y(0.04):.1f}" rx="2" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
# Windows.
for a, b in ((4.031, 2.58), (5.845, 4.422), (7.082, 6.255), (11.28, 10.45), (13.37, 11.93), (15.08, 13.79), (16.98, 15.60), (18.80, 17.52), (20.71, 19.41), (22.73, 21.41), (24.91, 23.27)):
    win(a, b)
# Door: outline from the leaves' top, split, two panes.
d.add(f'<rect x="{x(9.648):.1f}" y="{y(0.182):.1f}" width="{x(7.848) - x(9.648):.1f}" height="{BASE - y(0.182) - 1:.1f}" rx="3" fill="none" stroke="#8d949c" stroke-width="1.6"/>')
d.add(f'<line x1="{x(8.776):.1f}" y1="{y(0.182) + 2:.1f}" x2="{x(8.776):.1f}" y2="{BASE - 3}" stroke="#2b3037" stroke-width="1.2"/>')
for a, b in ((9.480, 8.923), (8.628, 8.062)):
    d.add(f'<rect x="{x(a):.1f}" y="{y(0.296):.1f}" width="{x(b) - x(a):.1f}" height="{y(0.669) - y(0.296):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
# Cab door: window, outline round window and panel, rain strip.
d.add(f'<rect x="{x(1.75):.1f}" y="{y(0.198):.1f}" width="{x(0.99) - x(1.75):.1f}" height="{y(0.491) - y(0.198):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
d.add(f'<rect x="{x(1.75):.1f}" y="{y(0.198):.1f}" width="{x(0.99) - x(1.75):.1f}" height="{y(0.669) - y(0.198):.1f}" rx="4" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
d.add(f'<line x1="{x(1.89):.1f}" y1="{y(0.166):.1f}" x2="{x(0.93):.1f}" y2="{y(0.166):.1f}" stroke="#2b3037" stroke-width="1.6" stroke-linecap="round"/>')
# Rubber nose (black) from the body's front end.
d.add(
    f'<path d="M{x(0.44):.1f},{ROOF - 4} V{y(0.95):.1f} H{TIP + 10} V{ROOF - 4} Z" fill="#1d2025"/>'
)
d.add(f'<path d="M{x(0.36):.1f},{y(0.06):.1f} C{x(0.16):.1f},{y(0.10):.1f} {x(0.05):.1f},{y(0.25):.1f} {x(0.03):.1f},{y(0.45):.1f}" fill="none" stroke="#ffffff" stroke-opacity="0.16" stroke-width="2.2" stroke-linecap="round"/>')
d.add(f'<line x1="{x(0.44):.1f}" y1="{ROOF + 2}" x2="{x(0.44):.1f}" y2="{BASE}" stroke="#000" stroke-opacity="0.25" stroke-width="1.2"/>')
d.end()

# Underframe, bogies, the lower front under the rubber nose.
d.add(f'<rect x="{x(20.3):.1f}" y="{BASE}" width="{x(3.8) - x(20.3):.1f}" height="6" fill="#4b5158"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{BASE}" width="{S - 0.4 * M - d.VB_X + 10:.1f}" height="6" fill="#4b5158"/>')
for c in (21.9, 2.1):
    bogie(c)
d.add(f'<path d="M{x(0.44):.1f},{y(0.95):.1f} H{x(0.10):.1f} L{x(0.12):.1f},{y(1.12):.1f} L{x(0.55):.1f},{y(1.14):.1f} L{x(0.75):.1f},{BASE} H{x(0.44):.1f} Z" fill="#3b4148"/>')

COMMENT = '// Öresundståg X31K (Bombardier Contessa) cab car, side view to scale. Generated by scripts/trains/x31.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'X31.tsx')
if __name__ == '__main__':
    main(d, 'X31Side', COMMENT, OUT)
