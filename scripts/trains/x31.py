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
- Owner's photos (2026-10-22): X31K 4600 (current livery, 3/4), 4580 (older Transitio livery, near side view: used
  for the nose, plough and cab window through a perspective fit on the door and cab window, residuals <4 px),
  4334 (3/4), 4547 (front 3/4), "5253" (original 2000 livery with the blue window band).
- DSB: DSB's ET units (the same Contessa) ran in the Öresundståg pool in this livery: ET 4342, DSB-owned, at Ørestad
  2024-04-11 (danskejernbaner.dk, photo Jacob Laursen). 24 of DSB's 34 sets went to Skånetrafiken in Dec 2022 and
  Region Skåne bought the last 10 in May 2023 (järnväg.net x31k; sv.wikipedia X31: all Swedish-owned since 2023), so
  DSB runs none now. The white/silver livery with a dark blue band (owner's photo 59, jernbanen.dk "DSB ET original")
  is the original 2000 livery, replaced in the 2018–2023 refurbishment: outdated, not drawn. `dsb` therefore shows the
  same current paint as `oresundstag`.
- Skånetrafiken/Öresundståg design drawing (above): wheel centre 3.29 m and wheel bottom 3.69 m below the roof,
  bogie centre 3.26 m from the car end. jernbanen.dk side drawing of one ET car (DSB_ET1.gif, 17.2 px/m from its door):
  door and cab window agree with the photos within 0.1 m; front bogie centre 3.44 m.
Measuring (Växjö photo, 1203x756): the window band's top and bottom edges are straight lines that meet at the
vanishing point u=8394 px (top y=0.02437u+457.26, bottom y=0.01679u+520.89, rms 0.3 px). Along the side,
X(u) = C(1/(8394-u) - 1/(8394-u_tip)) with C=896150 set by the door's width, 1.80 m (design drawing); the windows
then come out at 1.459 and 1.431 m, against 1.45 m in the drawing. Heights: the band is 0.882 m tall and its top
0.989 m below the roof (design drawing); body side 2.77 m to the bottom of the silver (then a dark skirt to 2.95 m).
Measured (metres back from the nose tip; f = fraction of body height down from the roof):
- rubber nose (rectified Växjö photo, checked on 4580): body ends 0.47 m; rubber top flush with the roof, top-front
  corner through (0.31, f 0.02) (0.25, 0.045) (0.156, 0.10) (0.11, 0.19) (0.085, 0.35); front 0.074–0.076 m from
  f 0.58 to 0.79; bottom f 0.915 (4580: 0.90–0.94). Below it the dark coupler pocket 0.47–0.20 m to f 1.07.
- plough (4580): rear edge 0.60 m at f 1.05 to 0.48 m at f 1.20, bottom f 1.20 forward to 0.10 m, front at 0.0–0.05
- side window band f 0.357–0.675; dark lower skirt f 1.0–1.065 along the car (4580, 4342)
- windows: 2.58–4.03, 4.42–5.85, 6.26–7.08 | door | 10.45–11.28, then (Lund perspective fit) 11.93–13.37,
  13.79–15.08, 15.60–16.98, 17.52–18.80, 19.41–20.71, 21.41–22.73, 23.27–24.91; pillars between are body colour
- door 7.85–9.65 m, leaves from f 0.182 down, split 8.78; panes 8.06–8.63 and 8.92–9.48, f 0.296–0.669
- paint: dark grey door zone 7.85–9.65 roof to underside; dark grey panels in the band 7.08–7.85 and 9.65–10.45;
  two red stripes 8.66–8.75 and 8.81–8.89 the full height, #e0533f: they read red-orange in 4600 (214,85,72),
  Halmstad 2024 (241,80,66) and 4342 (204,91,68), close to the red lettering; Växjö reads warmer (sunlit).
  Destination display 8.07–9.47, f 0.055–0.134
- cab door: glass 1.72–1.03 m, f 0.192–0.496 in a thin silver frame; dark grey panel 1.73–0.99 m, f 0.47–0.666 under
  it (the "dark band" round the window's lower half); rain strip 1.91–0.92 at f 0.164
- roof hatches 6.24–7.08 and 4.46–5.85, f 0.04–0.15 (seen on the roof shoulder)
- car body ends 25.3 m (Örsjö side-on 25.2–25.4, Lund fit 25.2); gangway 0.6 m (two 0.31 m bellows)
- bogies: rear centre 22.0 m (3.26 m from the end, as the design drawing's middle car); front 3.3 m (DSB_ET1 drawing
  3.44, 4580 photo 3.0–3.1 after its inset correction; ±0.2 m). Wheels drawn behind the bogie frame, only their lower
  part showing, as in every photo.
Not drawn: lettering and logos; the pantograph (on the middle car).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

OT, DSB = 'oresundstag', 'dsb'
PAINT = (OT, DSB)  # DSB's ET units run in the same Öresundståg paint (see docstring)
d = Drawing(car_m=25.3, body_m=2.77, gangway_m=0.6, liveries=[OT, DSB])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('silver', ['#f3f4f6', '#e4e6e9', '#c8ccd1'])
d.gradient('rubber', ['#2a2d33', '#1d2025', '#15171b'])
DOORGREY, PANEL, STRIPE = '#4b4a4c', '#66676f', '#e0533f'
BAND = (0.357, 0.675)
SKIRT = 1.065  # dark lower skirt along the car, f 1.0–1.065 (0.18 m)


def win(m0, m1):
    d.windows(x(m0), x(m1), 1, BAND[0] + 0.012, BAND[1] - 0.012)


def smooth(pts):
    """Catmull-Rom through (m, f) points -> SVG cubic segments (after an M to the first point)."""
    P = [(x(m), y(f)) for m, f in pts]
    out = []
    for i in range(len(P) - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, len(P) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return f'M{P[0][0]:.1f},{P[0][1]:.1f} ' + ' '.join(out)


WHEEL_F, WHEEL_R = 1.188, 0.415 * 40  # official drawing: wheel centre 3.29 m below the roof, rail 3.69 m (f 1.332)


def bogie(cm, axle_m=2.6):
    """Wheels behind the bogie frame: only their lower part shows, as in the photos."""
    cx, s = x(cm), axle_m * M / 2
    wy = y(WHEEL_F)
    for k in (-s, s):
        d.add(f'<circle cx="{cx + k:.1f}" cy="{wy:.1f}" r="{WHEEL_R:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
        d.add(f'<circle cx="{cx + k:.1f}" cy="{wy:.1f}" r="4" fill="#6d7681"/>')
    # Frame and equipment: from the skirt down to just below the axle line, over the wheels' tops.
    x0, x1 = cx - s - WHEEL_R - 4, cx + s + WHEEL_R + 4
    d.add(
        f'<path d="M{x0:.1f},{y(SKIRT):.1f} H{x1:.1f} V{y(1.17):.1f} Q{x1:.1f},{y(1.21):.1f} {x1 - 8:.1f},{y(1.21):.1f} '
        f'H{cx + s + 7:.1f} V{y(1.185):.1f} H{cx - s - 7:.1f} V{y(1.21):.1f} H{x0 + 8:.1f} Q{x0:.1f},{y(1.21):.1f} {x0:.1f},{y(1.17):.1f} Z" '
        f'fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>'
    )
    d.add(f'<line x1="{cx - 14:.1f}" y1="{y(1.13):.1f}" x2="{cx + 14:.1f}" y2="{y(1.11):.1f}" stroke="#6d7681" stroke-width="2.4" stroke-linecap="round"/>')


# ---- Second car: the middle car's end (design drawing: window from 0.67 m to 2.1 m from its end). ----
S = d.SECOND_END
d.clip('c2', f'M{d.VB_X - 10},{ROOF} H{S - 5} Q{S},{ROOF} {S},{ROOF + 5} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#silver)"/>')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="4" fill="url(#roof)"/>')
d.windows(S - 2.1 * M, S - 0.67 * M, 1, BAND[0] + 0.012, BAND[1] - 0.012)
d.end()
d.add(f'<rect x="{d.VB_X - 10}" y="{BASE}" width="{S - d.VB_X + 10:.1f}" height="{y(SKIRT) - BASE:.1f}" fill="#3b4148"/>')
d.gangway()

# ---- Cab car body (to its front end at 0.47 m; the rubber nose is drawn over it). ----
d.clip('c1', f'M{REAR},{BASE} V{ROOF + 5} Q{REAR},{ROOF} {REAR + 5},{ROOF} H{x(0.47) - 6:.1f} Q{x(0.47):.1f},{ROOF} {x(0.47):.1f},{ROOF + 6} V{BASE} Z')
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{d.H + 8}" fill="url(#silver)"/>')
d.add(f'<rect x="{REAR}" y="{ROOF}" width="{x(0.47) - REAR:.1f}" height="4" fill="url(#roof)"/>')
# Paint: dark grey door zone, the band panels beside it, the red stripes, the panel under the cab door window.
d.paint(f'<rect x="{x(9.648):.1f}" y="{ROOF - 2}" width="{x(7.848) - x(9.648):.1f}" height="{BASE - ROOF + 2}" rx="4" fill="{DOORGREY}"/>', PAINT)
for a, b in ((10.45, 9.648), (7.848, 7.082)):
    d.paint(f'<rect x="{x(a):.1f}" y="{y(BAND[0]):.1f}" width="{x(b) - x(a):.1f}" height="{y(BAND[1]) - y(BAND[0]):.1f}" fill="{PANEL}"/>', PAINT)
d.paint(f'<rect x="{x(1.73):.1f}" y="{y(0.47):.1f}" width="{x(0.99) - x(1.73):.1f}" height="{y(0.666) - y(0.47):.1f}" rx="4" fill="{PANEL}"/>', PAINT)
# Destination display above the door (equipment, every version).
d.add(f'<rect x="{x(9.47):.1f}" y="{y(0.055):.1f}" width="{x(8.07) - x(9.47):.1f}" height="{y(0.134) - y(0.055):.1f}" rx="1.5" fill="#14181e"/>')
for a, b in ((8.894, 8.805), (8.746, 8.657)):
    d.paint(f'<rect x="{x(a):.1f}" y="{ROOF - 2}" width="{x(b) - x(a):.1f}" height="{BASE - ROOF + 2}" fill="{STRIPE}"/>', PAINT)
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
# Cab door: window in a thin frame, outline round window and panel, rain strip.
d.add(f'<rect x="{x(1.72):.1f}" y="{y(0.192):.1f}" width="{x(1.03) - x(1.72):.1f}" height="{y(0.496) - y(0.192):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
d.add(f'<rect x="{x(1.73):.1f}" y="{y(0.18):.1f}" width="{x(0.99) - x(1.73):.1f}" height="{y(0.666) - y(0.18):.1f}" rx="4" fill="none" stroke="#8d949c" stroke-width="1.2"/>')
d.add(f'<line x1="{x(1.91):.1f}" y1="{y(0.164):.1f}" x2="{x(0.92):.1f}" y2="{y(0.164):.1f}" stroke="#2b3037" stroke-width="1.6" stroke-linecap="round"/>')
d.end()

# Dark lower skirt along the cab car, and the dark front structure below the rubber (coupler pocket).
d.add(f'<rect x="{REAR}" y="{BASE}" width="{x(0.47) - REAR:.1f}" height="{y(SKIRT) - BASE:.1f}" fill="#3b4148"/>')
d.add(f'<path d="M{x(0.47):.1f},{y(0.88):.1f} H{x(0.20):.1f} V{y(1.07):.1f} H{x(0.47):.1f} Z" fill="#2a2f36"/>')
# Snow plough under the nose (4580 photo, through its perspective fit).
d.add(f'<path d="{smooth([(0.60, 1.05), (0.56, 1.10), (0.52, 1.17), (0.48, 1.20)])} L{x(0.10):.1f},{y(1.20):.1f} Q{x(0.0):.1f},{y(1.195):.1f} {x(0.0):.1f},{y(1.12):.1f} L{x(0.05):.1f},{y(1.05):.1f} Z" fill="#3b4148" stroke="#4d5560" stroke-width="1"/>')
# Equipment between the bogies, and the bogies (front 3.3 m, rear 22.0 m; axles 2.6 m, wheels 0.83 m).
d.add(f'<rect x="{x(20.4):.1f}" y="{y(SKIRT):.1f}" width="{x(4.9) - x(20.4):.1f}" height="{y(1.12) - y(SKIRT):.1f}" fill="#2a2f36"/>')
for c in (22.0, 3.3):
    bogie(c)
d.add(f'<rect x="{d.VB_X - 10}" y="{y(SKIRT):.1f}" width="{S - 0.3 * M - d.VB_X + 10:.1f}" height="{y(1.12) - y(SKIRT):.1f}" fill="#2a2f36"/>')
# Rubber nose: the black end, 0.47 m deep, rounded top-front corner, front at 0.07 m, bottom at f 0.915.
nose = [(0.47, 0.0), (0.31, 0.02), (0.25, 0.045), (0.156, 0.10), (0.11, 0.19), (0.085, 0.35), (0.074, 0.58), (0.076, 0.79), (0.10, 0.87), (0.17, 0.905), (0.26, 0.915)]
d.add(f'<path d="{smooth(nose)} L{x(0.47):.1f},{y(0.915):.1f} Z" fill="url(#rubber)" stroke="#4d5560" stroke-width="1.4"/>')
d.add(f'<path d="{smooth([(0.40, 0.035), (0.25, 0.07), (0.15, 0.14), (0.11, 0.26), (0.10, 0.45)])}" fill="none" stroke="#ffffff" stroke-opacity="0.16" stroke-width="2.2" stroke-linecap="round"/>')
d.add(f'<line x1="{x(0.47):.1f}" y1="{ROOF + 2}" x2="{x(0.47):.1f}" y2="{y(0.915):.1f}" stroke="#000" stroke-opacity="0.35" stroke-width="1.2"/>')

if __name__ == '__main__':
    main(d)
