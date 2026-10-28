"""DSB's EB with a Talgo 230 set, as on Copenhagen-Hamburg since November 2025: a Siemens Vectron AC locomotive (class
EB) and the end car of the Talgo set, side view. docs/TRAIN_ART.md; layout as dk_eb_dd.py and snalltaget.py (the loco
whole, cab to the right, the start of the first coach). Liveries: `dsb` (the loco as dk_eb_dd.py; the Talgo cars red
with a black window band, grey roof and underframe, light grey door leaves), plus `plain`.

The loco is dk_eb_dd.py's (snalltaget.py's geometry, DSB paint; sources there), copied unchanged; 180.webp (below), a
real photo of EB 3231, confirms its paint: grey roof and cab tops, the grey coming down each cab towards the bottom of
the windscreen, red sides, dark grey underframe band.

Sources:
- Garner's photos (2026-10-28): 179.webp (a DSB Talgo end car in pure side view, the loco end to the right: measured,
  below), 180.webp (EB 3231 with a Talgo set at a Danish station: the end car's raised section faces the loco), 178.png
  (cars at Talgo's factory, 3/4: the door leaves light grey, the band black).
- Talgo 230 family (en.wikipedia "ICE L", seen through a search summary on 2026-10-28, the page itself not reachable from
  here): middle cars 13.3 m and end cars 18.3 m long, height 3.6 m (middle cars) and 3.8 m (end cars), floor 760 mm.
  These are the DB version's figures; DSB's cars are assumed the same (unverified).
- 179.webp scale: rail top y 375, roof top y 220 = the end car's 3.8 m, so 40.8 px per metre; the end bogie's
  wheelbase then comes out 2.6 m, which is plausible. Measured on it (metres from the car's loco end, heights above
  rail): roof top 3.80, rounded into the end over about 0.5 m; grey roof down to 3.36; end module seam 0.47 m; red
  body down to 1.15 over the raised section (the end bogie, wheels at 3.5 and 6.1 m), stepping down near 7.2 m to
  0.69 over the low floor, with a dark grey band 0.44-0.69 below; black window band 2.08-3.06 from 1.79 m back to
  8.1 m (windows 2.11-2.94: 1.79-2.48, 3.09-4.44, 4.81-6.16, 6.53-7.19); grey equipment boxes under the end
  (drawn as part of the underframe skirt).
Estimated: the gap between the loco's buffer face and the car end (0.55 m, as dk_eb_dd.py); the colours' shades (a
photo in overcast light). The first 6.85 m of the car shows, with its end bogie
(wheel size, frame outline and the axle boxes estimated from the small photo); the door (8.1-9.3 m) and the low-floor
section are outside the picture.
The underframe is simplified to one dark grey skirt (0.82-1.15 m) along the car, the equipment boxes in it; the
bogie's frame, the wheel size and the coupler are estimated from 179.webp at its small size.
Not drawn: the DSB logos, the bike and pram pictograms, numbers and lettering, the coupling, small signs.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

ST = 'dsb'
CAR, SHOW = 18.98, 7.4
TOP = 4.4  # view top (m above rail)
DR = 0.15  # the standard roof is this much lower than the Sr3's


class VectronDrawing(Drawing):
    """The kit's drawing with heights in metres above rail and a view box from the pantographs down to the rail."""

    def viewbox(self):
        top = self.Y(TOP - 0.05)
        return f'{self.VB_X:.0f} {top:.0f} {self.TIP + 8 - self.VB_X:.0f} {self.Y(-0.05) - top:.0f}'

    def Y(self, h):
        return self.ROOF + (TOP - h) * self.M


d = VectronDrawing(car_m=CAR, body_m=TOP, show_second_m=SHOW, gangway_m=0.0, liveries=[ST])
x, Y, M = d.x, d.Y, d.M
d.gradient('stred', ['#e6303a', '#da2630', '#c11f28'], stops=(0, 0.55, 1))
d.gradient('stdark', ['#585a5d', '#46494c'])
d.gradient('stroof', ['#6d7378', '#5c6268'])
d.gradient('capgrey', ['#a3a8ae', '#8d9399'])
d.gradient('band', ['#26292d', '#1a1c1f'])
RAILC = '#b4b9be'
DOOR_ST = '#a51c22'


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def poly(pts, fill, only=None, extra=''):
    d.add(f'<path d="M{" L".join(P(m, h) for m, h in pts)} Z" fill="{fill}"{extra}/>', only)


def line(m0, h0, m1, h1, stroke, w=1.2, only=None, extra=''):
    d.add(f'<line x1="{x(m0):.1f}" y1="{Y(h0):.1f}" x2="{x(m1):.1f}" y2="{Y(h1):.1f}" stroke="{stroke}" stroke-width="{w}"{extra}/>', only)


def smooth(pts):
    """Catmull-Rom through (m, h) points -> SVG cubic segments (no leading M)."""
    Q = [(x(m), Y(h)) for m, h in pts]
    out = []
    for i in range(len(Q) - 1):
        p0, p1, p2, p3 = Q[max(i - 1, 0)], Q[i], Q[i + 1], Q[min(i + 2, len(Q) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return ' '.join(out)


def mir(pts):
    return [(CAR - m, h) for m, h in pts]


# ---------------------------------------------------------------- the Talgo end car, behind the loco (179.webp)
CE = CAR + 0.55            # the car's loco end (estimated, as dk_eb_dd.py)
CL = CAR + SHOW + 0.3      # beyond the picture's left edge
ROOF_T, SHOULDER = 3.80, 0.50
ROOF_EDGE, BOTTOM = 3.36, 1.15
BAND = (2.08, 3.06)
d.clip('coach', f'M{x(CL):.1f},{Y(BOTTOM):.1f} V{Y(ROOF_T):.1f} H{x(CE + SHOULDER):.1f} '
       f'Q{x(CE):.1f},{Y(ROOF_T):.1f} {x(CE):.1f},{Y(ROOF_T - SHOULDER):.1f} V{Y(BOTTOM):.1f} Z')
d.group('coach')
rect(CL, CE - 0.1, BOTTOM - 0.05, ROOF_T + 0.1, 'url(#body)', 'plain')
rect(CL, CE - 0.1, BOTTOM - 0.05, ROOF_T + 0.1, 'url(#stred)', ST)
rect(CL, CE - 0.1, ROOF_EDGE, ROOF_T + 0.1, 'url(#roof)', 'plain')
rect(CL, CE - 0.1, ROOF_EDGE, ROOF_T + 0.1, 'url(#stroof)', ST)
line(CL, ROOF_EDGE, CE, ROOF_EDGE, '#000', 1.0, extra=' stroke-opacity="0.2"')
rect(CL, CE + 1.79, BAND[0], BAND[1], 'url(#band)', ST)
line(CE + 0.47, ROOF_EDGE - 0.05, CE + 0.47, BOTTOM + 0.05, '#000', 1.0, extra=' stroke-opacity="0.25"')
d.end()
# The window at 1.79-2.48 m, and the start of the next at 3.09 m.
for a, b in ((CE + 1.79, CE + 2.48), (CE + 3.09, CE + 4.44), (CE + 4.81, CE + 6.16), (CE + 6.53, CE + 7.19)):
    rect(a + 0.04, b - 0.04, 2.11, 2.94, '#0b0d10', rx=4)
    rect(a + 0.08, b - 0.08, 2.15, 2.90, 'url(#glass)', rx=3)
# Underneath, drawn as one piece as on the loco: a continuous dark grey underframe skirt along the car, from the end
# (where the coupler goes in) back past the bogie, and the end bogie under it (179.webp: wheels at 3.5 and 6.1 m,
# about 0.84 m). The equipment boxes of 179 are drawn as part of the skirt, not as separate boxes.
SKIRT = 0.82
TWR = 0.42
for a in (CE + 3.5, CE + 6.1):
    d.add(f'<circle cx="{x(a):.1f}" cy="{Y(TWR):.1f}" r="{TWR * M - 1:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
    d.add(f'<circle cx="{x(a):.1f}" cy="{Y(TWR):.1f}" r="{0.30 * M:.1f}" fill="none" stroke="#3a4048" stroke-width="1.6" stroke-dasharray="2 3"/>')
frame = (f'M{P(CE + 2.85, SKIRT)} H{x(CE + 6.75):.1f} V{Y(0.66):.1f} H{x(CE + 6.62):.1f} '
         f'Q{P(CE + 6.1, 1.00)} {P(CE + 5.58, 0.66)} L{P(CE + 5.45, 0.40)} H{x(CE + 4.15):.1f} L{P(CE + 4.02, 0.66)} '
         f'Q{P(CE + 3.5, 1.00)} {P(CE + 2.98, 0.66)} H{x(CE + 2.85):.1f} Z')
d.add(f'<path d="{frame}" fill="#363c44" stroke="#4d5560" stroke-width="1.2"/>')
for a in (CE + 3.5, CE + 6.1):
    rect(a - 0.12, a + 0.12, SKIRT, 0.32, '#2f353d', rx=2, extra=' stroke="#4d5560" stroke-width="1"')
    d.add(f'<circle cx="{x(a):.1f}" cy="{Y(TWR):.1f}" r="5" fill="#6d7681"/>')
skirt = (f'M{x(CL):.1f},{Y(BOTTOM + 0.03):.1f} H{x(CE):.1f} V{Y(SKIRT + 0.12):.1f} '
         f'Q{P(CE, SKIRT)} {P(CE + 0.12, SKIRT)} H{x(CL):.1f} Z')
d.add(f'<path d="{skirt}" fill="#3a3f46" stroke="#4d5560" stroke-width="1"/>', ST)
d.add(f'<path d="{skirt}" fill="#8d949c" stroke="#7a8189" stroke-width="1"/>', 'plain')
# End wall and gangway between the vehicles; the loco's coupling side.
rect(CAR + 0.02, CE, 1.2, 3.55, '#2b3037')
for i in range(1, 4):
    m = CAR + 0.02 + i * (CE - CAR - 0.02) / 4
    line(m, 1.25, m, 3.50, '#41474f', 1.3)
rect(CAR, CAR + 0.30, 0.82, 1.12, '#3a4048', rx=1.5)
rect(CAR + 0.30, CE, 0.88, 1.06, '#2a2f36')  # the coupler bar, into the car's skirt
rect(CE - 0.10, CE + 0.04, 0.86, 1.08, '#3a4048', rx=1.5)

# ---------------------------------------------------------------- loco running gear (behind the body)
WR = 0.625
BOGIES = (CAR / 2 - 4.75, CAR / 2 + 4.75)


def bogie(c):
    """Vectron bogie as fi_sr3_ic.py: the wheels behind the dark frame (arched over each wheel), axle boxes and coil
    springs at the wheels, a damper along the frame."""
    for a in (c - 1.5, c + 1.5):
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WR):.1f}" r="{WR * M - 1:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WR):.1f}" r="{0.45 * M:.1f}" fill="none" stroke="#3a4048" stroke-width="1.6" stroke-dasharray="2 3"/>')
    frame = (f'M{P(c - 2.25, 0.97)} H{x(c + 2.25):.1f} V{Y(0.80):.1f} H{x(c + 2.15):.1f} '
             f'Q{P(c + 1.5, 1.42)} {P(c + 0.85, 0.80)} L{P(c + 0.75, 0.39)} H{x(c - 0.75):.1f} L{P(c - 0.85, 0.80)} '
             f'Q{P(c - 1.5, 1.42)} {P(c - 2.15, 0.80)} H{x(c - 2.25):.1f} Z')
    d.add(f'<path d="{frame}" fill="#363c44" stroke="#4d5560" stroke-width="1.2"/>')
    for a in (c - 1.5, c + 1.5):
        rect(a - 0.13, a + 0.13, 0.95, 0.40, '#2f353d', rx=2, extra=' stroke="#4d5560" stroke-width="1"')
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WR):.1f}" r="5" fill="#6d7681"/>')
    for s in (-1, 1):
        for k in range(4):
            line(c + s * 1.75, 0.93 - k * 0.07, c + s * 2.05, 0.93 - k * 0.07, '#8b939b', 2.0, extra=' stroke-linecap="round"')
    rect(c - 0.55, c + 0.55, 0.62, 0.70, '#7d858d', rx=2)


rect(CAR / 2 - 2.05, CAR / 2 + 2.05, 1.02, 0.39, '#2a2f36', rx=2, extra=' stroke="#3f464f" stroke-width="1.2"')
for c in BOGIES:
    bogie(c)


def plough(sign):
    def m(v):
        return v if sign > 0 else CAR - v
    poly([(m(2.0), 1.02), (m(1.30), 1.02), (m(1.18), 0.19), (m(1.60), 0.19), (m(1.98), 0.45)], '#2f353c', extra=' stroke="#4d5560" stroke-width="1"')


def ladder(sign):
    def m(v):
        return v if sign > 0 else CAR - v
    for v in (2.80, 3.10):
        line(m(v), 0.97, m(v), 0.40, '#59616b', 1.8)
    for hh in (0.78, 0.58, 0.42):
        line(m(2.80), hh, m(3.10), hh, '#59616b', 1.8)


for s in (1, -1):
    plough(s)
    ladder(s)

# ---------------------------------------------------------------- loco body
NOSE = [(1.91, 3.60), (1.61, 3.49), (1.32, 3.24), (1.11, 2.87), (0.98, 2.50), (0.81, 2.20), (0.87, 1.96), (0.85, 1.63), (0.87, 1.37)]
DECK, HOOD = 3.66 - DR, 3.95 - DR
outline = (f'M{P(CAR - 0.87, 1.37)} {smooth(mir(NOSE)[::-1])} L{P(CAR - 3.78, 3.60)} L{P(CAR - 3.78, DECK)} L{P(CAR - 4.87, DECK)} '
           f'L{P(CAR - 5.22, HOOD)} L{P(5.22, HOOD)} L{P(4.87, DECK)} L{P(3.78, DECK)} L{P(3.78, 3.60)} L{P(1.91, 3.60)} '
           f'{smooth(NOSE)} L{P(0.87, 0.97)} L{P(CAR - 0.87, 0.97)} Z')
d.clip('loco', outline)
d.group('loco')
rect(0.5, CAR - 0.5, 0.9, 4.0, 'url(#body)', 'plain')
rect(0.5, CAR - 0.5, 0.9, 4.0, 'url(#stred)', ST)
rect(3.78, CAR - 3.78, 3.10, 4.0, 'url(#roof)', 'plain')
# The grey cab caps (169.webp): above the body side's top, and down each cab in a curve from the cab joint at the roof
# to the bottom of the windscreen at the nose; the corner at the joint rounded as on the model.
CAP_CURVE = [(1.70, 2.95), (1.61, 2.76), (1.46, 2.54), (1.26, 2.41), (1.00, 2.34), (0.60, 2.30), (-0.2, 2.28)]
for pts in (CAP_CURVE, mir(CAP_CURVE)):
    j = pts[0][0] + (0.05 if pts is CAP_CURVE else -0.05)  # the cab joint
    e = 3.80 if pts is CAP_CURVE else CAR - 3.80
    t = 1.95 if pts is CAP_CURVE else CAR - 1.95
    d.add(f'<path d="M{P(e, 4.3)} L{P(e, 3.10)} L{P(t, 3.10)} Q{P(j, 3.10)} {P(*pts[0])} {smooth(pts)} '
          f'L{P(pts[-1][0], 4.3)} Z" fill="url(#capgrey)"/>', ST)
rect(3.78, CAR - 3.78, 3.10, 4.0, 'url(#stroof)', ST)
for m in (1.75, CAR - 1.75):  # cab joints
    line(m, 3.12, m, 1.37, '#000', 1.0, extra=' stroke-opacity="0.3"')
d.end()
line(3.78, 3.10, CAR - 3.78, 3.10, '#000', 1.0, extra=' stroke-opacity="0.25"')
line(5.22, HOOD, CAR - 5.22, HOOD, '#5b636b', 1.0, ST)  # the hood's top edge catching the light
rect(0.87, CAR - 0.87, 1.37, 0.97, 'url(#stdark)', ST)
rect(0.87, CAR - 0.87, 1.37, 0.97, '#8d949c', 'plain')
line(0.87, 1.37, CAR - 0.87, 1.37, '#000', 1.0, extra=' stroke-opacity="0.25"')
# The windscreen seen side-on: the Sr3's field (estimated there), ended 0.25 m ahead of the cab joint, since 169.webp
# shows a grey pillar between the glass and the joint (0.3-0.6 m on the model; unverified on the real locos).
FIELD = [(1.50, 3.03), (1.46, 2.89), (1.24, 2.66), (1.13, 2.46), (1.50, 2.46)]
for pts in (FIELD, mir(FIELD)):
    poly(pts, '#1d2228', ST, extra=' stroke-linejoin="round"')
    poly(pts, '#59616b', 'plain', extra=' stroke-linejoin="round"')
rect(0.86, 0.98, 1.42, 1.95, '#1d2228', rx=2)
rect(CAR - 0.86, CAR - 0.98, 1.42, 1.95, '#1d2228', rx=2)


def window(m0, m1, h0, h1):
    rect(m0, m1, h0, h1, '#0b0d10', rx=4)
    rect(m0 - 0.04, m1 + 0.04, h0 - 0.04, h1 + 0.04, 'url(#glass)', rx=3)


def cab(sgn):
    def m(v):
        return v if sgn > 0 else CAR - v
    a, b = sorted((m(2.66), m(3.30)))
    rect(a, b, 1.48, 3.10, 'none', ST, rx=3, extra=f' stroke="{DOOR_ST}" stroke-width="1.4"')
    rect(a, b, 1.48, 3.10, 'none', 'plain', rx=3, extra=' stroke="#8d949c" stroke-width="1.4"')
    a, b = sorted((m(2.77), m(3.21)))
    window(b, a, 3.01, 2.43)
    for v in (2.63, 3.34):
        rect(m(v) - 0.02, m(v) + 0.02, 1.32, 3.06, RAILC, rx=1)


cab(1)
cab(-1)
for face in (0.0, CAR):  # buffers and buffer beams
    s = 1 if face == 0 else -1
    rect(face + s * 0.28, face + s * 0.87, 0.70, 1.37, '#36393d', ST)
    rect(face + s * 0.28, face + s * 0.87, 0.70, 1.37, '#7d858d', 'plain')
    rect(face + s * 0.10, face + s * 0.30, 0.86, 1.08, '#3a4048')
    rect(face, face + s * 0.10, 0.80, 1.14, '#2f353c', rx=1.5)

# ---------------------------------------------------------------- pantographs (folded), 0.15 m lower than the Sr3's


def pantograph(sgn):
    def m(v):
        return v if sgn > 0 else CAR - v
    for v in (3.61, 4.32):
        rect(m(v) - 0.07, m(v) + 0.07, DECK, 4.06 - DR, '#5b5550', rx=1)
    rect(m(2.35), m(2.70), 3.60, 4.22 - DR, '#30353c', rx=1)
    rect(m(3.45), m(4.45), 4.06 - DR, 4.12 - DR, '#3a3f46', rx=1)
    for col, only in (('#c8262d', ST), ('#7d858d', 'plain')):  # lower arm (red on the 169.webp model; unverified on the real locos)
        d.add(f'<path d="M{P(m(2.20), 4.20 - DR)} L{P(m(4.40), 4.25 - DR)}" stroke="{col}" stroke-width="4" stroke-linecap="round" fill="none"/>', only)
    d.add(f'<path d="M{P(m(2.20), 4.27 - DR)} L{P(m(4.45), 4.31 - DR)}" stroke="#3a3f46" stroke-width="2.2" stroke-linecap="round" fill="none"/>')
    rect(m(4.40), m(4.78), 4.30 - DR, 4.36 - DR, '#5d646c', rx=1)
    d.add(f'<path d="M{P(m(4.78), 4.33 - DR)} Q{P(m(4.86), 4.33 - DR)} {P(m(4.86), 4.24 - DR)}" stroke="#5d646c" stroke-width="1.6" fill="none"/>')


pantograph(1)
pantograph(-1)

if __name__ == '__main__':
    main(d)
