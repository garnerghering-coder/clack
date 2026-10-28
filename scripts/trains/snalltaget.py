"""Snälltåget's train: a Siemens Vectron AC locomotive (standard gauge, Bo'Bo', the BR 193 family) hauling a silver
coach, side view. docs/TRAIN_ART.md; layout as rc6_coaches.py and fi_sr3_ic.py (the loco whole, cab to the right, the
start of the first coach). Liveries: `snalltaget` (red body, dark grey underframe band, black roof equipment, the
coach silver with a red end door), plus `plain`.

The loco's geometry is fi_sr3_ic.py's (the Finnish Vectron, measured side-on there), changed only where the standard
Vectron differs. de.wikipedia "Siemens Vectron" (action=raw, retrieved 2026-10-24): the Finnish locos have the same
body dimensions as the standard-gauge ones but higher roofs with taller grilles, a changed front with an anti-climber,
cab side windows with a mirror, and a step bulge instead of the separate access ladder. Standard AC Vectron: 18 980 mm
over buffers, height 4 250 mm (Sr3: 19 049 / 4 400), bogie centres 9 500, bogie axles 3 000, wheels 1 250 mm.
So: the body side, cab, nose, door, bogies and buffers as fi_sr3_ic.py with the length 18.98 m (mirrored about the
new middle, bogie centres 4.74 and 14.24); every roof height 0.15 m lower (decks 3.51, hoods 3.80, folded pantographs
4.22 m); no cab side window (the standard cab shows only the door window on the side); the access ladder kept.

Sources:
- Garner's photos (2026-10-24): 152.webp (the loco nearly side-on at Malmö, coach behind: the livery, and the checks
  below), 151.webp (loco and train, 3/4: the coaches silver with red end doors, one coach red), 153.png (at a lake, 3/4).
- Checks on 152.webp (3/4 from ahead, camera about 1.9 m above rail; a 1-D projective map along the side fitted on the
  front and rear cab doors, residuals 5-7 cm; vertical scale from the door window and sill): the red/black roof edge
  comes out 3.06-3.09 m (Sr3 body side top 3.10), the sill line 1.37-1.38 (Sr3 1.37), the standard cab without a side
  window, the separate access ladder under the cab door, black roof equipment starting right behind the cab roof, the
  pantographs' lower arms red, the upper arms and heads dark.
- Livery (152.webp): red #db2d25 in sun; a dark grey band 0.97-1.37 along the whole underframe, buffer beams included;
  the roof behind the cabs black from the body side's top (3.10) up. The white grille stripes are on the front face only
  (not seen side-on).
- Coach (152.webp, 151.webp): silver body and roof, a red end section with the entrance door and its narrow window, then
  even window rows (the first window narrower); windows 1.97-2.89, body bottom about 1.08, a dark skirt to 0.85, roof
  edge about 3.05 (152.webp, on the side plane by the same map). Its type is not confirmed (Snälltåget runs older
  German/Austrian-built coaches), so it is drawn simply: no grilles, no bogie.
Estimated: the coach's end position (0.55 m behind the loco's buffer face, as fi_sr3_ic.py), its roof height (4.0, a
UIC-type coach), the red section's length (1.35 m), its door (0.25-1.15) and window positions (from a 3/4 photo, about
0.2 m); the windscreen's side-on field (the Sr3's, cut at the cab joint); the snowplough (the Sr3's shape).
Not drawn: the LOKET / Snälltåget lettering and the S logo (trademarks), the coaches' coloured lettering wraps, numbers
and small signs, couplings and hoses, roof grille details (the standard roof's layout is not measured), the coach's bogie.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

ST = 'snalltaget'
CAR, SHOW = 18.98, 3.4
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
d.gradient('stred', ['#e4342c', '#d52b25', '#bd231f'], stops=(0, 0.55, 1))
d.gradient('stdark', ['#45484c', '#36393d'])
d.gradient('stroof', ['#2c3035', '#1f2226'])
d.gradient('silver', ['#e6e8ea', '#d6d9dc', '#bfc3c8'], stops=(0, 0.55, 1))
d.gradient('silverroof', ['#b9bec4', '#cfd3d7'])
d.gradient('sill', ['#66717a', '#55606a'])
RAILC = '#9aa1a8'
DOOR_ST = '#8e1b17'


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


# ---------------------------------------------------------------- the coach, behind the loco
CE = CAR + 0.55            # end of the coach side (estimated)
CL = CAR + SHOW + 0.3      # beyond the picture's left edge
ROOF_C, CAP, EAVE = 4.0, 0.40, 3.05
RED_END = CE + 1.35        # the red end section with the entrance door
d.clip('coach', f'M{x(CL):.1f},{Y(0.85):.1f} V{Y(ROOF_C):.1f} H{x(CE + CAP):.1f} Q{x(CE):.1f},{Y(ROOF_C):.1f} {x(CE):.1f},{Y(ROOF_C - CAP):.1f} V{Y(0.85):.1f} Z')
d.group('coach')
rect(CL, CE - 0.1, 0.8, ROOF_C + 0.1, 'url(#body)', 'plain')
rect(CL, CE - 0.1, 0.8, ROOF_C + 0.1, 'url(#silver)', ST)
rect(CL, CE - 0.1, EAVE, ROOF_C + 0.1, 'url(#roof)', 'plain')
rect(CL, CE - 0.1, EAVE, ROOF_C + 0.1, 'url(#silverroof)', ST)
rect(CE - 0.1, RED_END, 1.08, EAVE, 'url(#stred)', ST)
line(CL, EAVE, CE, EAVE, '#000', 1.0, extra=' stroke-opacity="0.2"')
rect(CL, CE - 0.1, 0.8, 1.08, 'url(#stdark)', ST)
rect(CL, CE - 0.1, 0.8, 1.08, '#8d949c', 'plain')
line(CE + CAP, EAVE + 0.05, CE + CAP, ROOF_C - 0.05, '#000', 1.0, extra=' stroke-opacity="0.2"')
d.end()
# Entrance door with its narrow window; the first two side windows.
rect(CE + 0.25, CE + 1.15, 1.12, 2.98, 'none', ST, rx=3, extra=f' stroke="{DOOR_ST}" stroke-width="1.4"')
rect(CE + 0.25, CE + 1.15, 1.12, 2.98, 'none', 'plain', rx=3, extra=' stroke="#8d949c" stroke-width="1.4"')
rect(CE + 0.50, CE + 0.90, 1.95, 2.85, '#0b0d10', rx=3)
rect(CE + 0.54, CE + 0.86, 1.99, 2.81, 'url(#glass)', rx=2)
for a, b in ((CE + 1.55, CE + 2.30), (CE + 2.65, CE + 3.85)):
    rect(a, b, 1.97, 2.89, '#0b0d10', rx=4)
    rect(a + 0.05, b - 0.05, 2.02, 2.84, 'url(#glass)', rx=3)
# End wall and gangway between the vehicles; the coach's buffer.
rect(CAR + 0.02, CE, 1.2, 3.85, '#2b3037')
for i in range(1, 4):
    m = CAR + 0.02 + i * (CE - CAR - 0.02) / 4
    line(m, 1.25, m, 3.80, '#41474f', 1.3)
rect(CAR, CAR + 0.30, 0.82, 1.12, '#3a4048', rx=1.5)
rect(CAR + 0.30, CE, 0.88, 1.06, '#2a2f36')

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
rect(3.78, CAR - 3.78, 3.10, 4.0, 'url(#stroof)', ST)
for m in (1.75, CAR - 1.75):  # cab joints
    line(m, 3.12, m, 1.37, '#000', 1.0, extra=' stroke-opacity="0.3"')
d.end()
line(3.78, 3.10, CAR - 3.78, 3.10, '#000', 1.0, extra=' stroke-opacity="0.25"')
line(5.22, HOOD, CAR - 5.22, HOOD, '#5b636b', 1.0, ST)  # the hood's top edge catching the light
rect(0.87, CAR - 0.87, 1.37, 0.97, 'url(#stdark)', ST)
rect(0.87, CAR - 0.87, 1.37, 0.97, '#8d949c', 'plain')
line(0.87, 1.37, CAR - 0.87, 1.37, '#000', 1.0, extra=' stroke-opacity="0.25"')
# The windscreen seen side-on (the Sr3's field, cut at the cab joint; estimated).
FIELD = [(1.75, 3.03), (1.46, 2.89), (1.24, 2.66), (1.13, 2.46), (1.75, 2.46)]
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
    for col, only in (('#b8302a', ST), ('#7d858d', 'plain')):  # lower arm (red on 152.webp)
        d.add(f'<path d="M{P(m(2.20), 4.20 - DR)} L{P(m(4.40), 4.25 - DR)}" stroke="{col}" stroke-width="4" stroke-linecap="round" fill="none"/>', only)
    d.add(f'<path d="M{P(m(2.20), 4.27 - DR)} L{P(m(4.45), 4.31 - DR)}" stroke="#3a3f46" stroke-width="2.2" stroke-linecap="round" fill="none"/>')
    rect(m(4.40), m(4.78), 4.30 - DR, 4.36 - DR, '#5d646c', rx=1)
    d.add(f'<path d="M{P(m(4.78), 4.33 - DR)} Q{P(m(4.86), 4.33 - DR)} {P(m(4.86), 4.24 - DR)}" stroke="#5d646c" stroke-width="1.6" fill="none"/>')


pantograph(1)
pantograph(-1)

if __name__ == '__main__':
    main(d)
