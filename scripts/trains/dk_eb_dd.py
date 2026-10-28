"""DSB's EB: a Siemens Vectron AC locomotive (class EB, 3201-) hauling a DSB double-deck coach, side view, as on
the Zealand regional trains. docs/TRAIN_ART.md; layout as snalltaget.py (the loco whole, cab to the right, the start of
the first coach). Liveries: `dsb` (red body, light grey cab caps and roof, dark grey underframe band; the coach silver
grey with a navy band), plus `plain`.

The loco is the same standard AC Vectron as snalltaget.py: its geometry (body outline, nose, cab door and window,
bogies, buffers, ladders, ploughs, pantographs) is copied from there unchanged, with the sources and measurements given
in that file. Only the paint and the coach differ.

Sources:
- Garner's photos (2026-10-28): 169.webp (Piko model of EB 3201, pure side view: where the colours meet), 168.png
  (Märklin model, 3/4), 170.png (EB 3238 at Copenhagen with double-deck coaches: the real colours, small), 171.webp
  (a DSB double-deck coach at København H, 3/4: the coach's paint and the window layout at its end).
- Loco livery (169.webp, the cab boundaries read relative to the cab joint and the door, the heights scaled between the
  roof edge 3.10 m and the sill 1.37 m of snalltaget.py, since the model's own heights are out of scale): red up to
  the body side's top (3.10); everything above it grey, the cab tops included, lighter on the cab caps than on the
  roof deck; on each cab the grey comes down from the cab joint at the roof (1.75 m from the buffer face, 3.10)
  in a curve, through about (1.46, 2.54) and (1.00, 2.34), passing just under the windscreen's side glass, to meet
  the nose a little below the windscreen (2.3; the two ends of the model disagree by about 0.1 m); a grey pillar
  between the side glass and the cab joint, so the glass is drawn ending 0.25 m ahead of the joint. Dark grey band 0.97-1.37 along the underframe and the buffer
  beams, as Snälltåget's. Red #e4252e (the model under studio light; 170.png agrees by eye).
- Coach (171.webp): light silver-grey body (#b5b9bc in shade), light roof, a navy band (#22253c) the full length at
  the level of the end section's windows, a dark grey (#595d62) skirt. Built by Bombardier in Görlitz (ing.dk, "DSB
  køber 67 dobbeltdækkervogne", 2014-03-21, https://ing.dk/artikel/dsb-koeber-67-dobbeltdaekkervogne, retrieved
  2026-10-28: the coaches are built by Bombardier in Görlitz).
Estimated, not measured: the coach's heights (roof 4.63 m, as the Görlitz double-deck family; navy band 2.30-3.35;
end-section windows 2.42-3.24; body bottom 1.05 at the end), read from 171.webp in perspective at about 0.1-0.15 m;
its window positions along the end section (about 0.2 m); its end 0.55 m behind the loco's buffer face, as
snalltaget.py. The loco's cab grey is a model's paint, checked only by eye against 170.png.
Not drawn: the DSB hexagon logos, numbers, lettering and small signs; the coach's grilles, door stripes and bogie (the
coach's doors are outside the part shown); couplings and hoses.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

ST = 'dsb'
CAR, SHOW = 18.98, 3.4
TOP = 4.75  # view top (m above rail): the double-deck coach's roof
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
d.gradient('silver', ['#d3d7da', '#c4c9cd', '#b0b5ba'], stops=(0, 0.55, 1))
d.gradient('silverroof', ['#c9ced2', '#dde0e3'])
d.gradient('navy', ['#2a2f48', '#22263c'])
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


# ---------------------------------------------------------------- the coach, behind the loco
CE = CAR + 0.55            # end of the coach side (estimated, as snalltaget.py)
CL = CAR + SHOW + 0.3      # beyond the picture's left edge
ROOF_C, SHOULDER = 4.63, 0.75   # double-deck roof (Görlitz family, unverified) and the end's rounded shoulder
EAVE, BOTTOM, SKIRT = 4.05, 1.05, 0.85
NAVY = (2.30, 3.35)
d.clip('coach', f'M{x(CL):.1f},{Y(SKIRT):.1f} V{Y(ROOF_C):.1f} H{x(CE + SHOULDER):.1f} '
       f'Q{x(CE):.1f},{Y(ROOF_C):.1f} {x(CE):.1f},{Y(ROOF_C - SHOULDER):.1f} V{Y(SKIRT):.1f} Z')
d.group('coach')
rect(CL, CE - 0.1, SKIRT - 0.05, ROOF_C + 0.1, 'url(#body)', 'plain')
rect(CL, CE - 0.1, SKIRT - 0.05, ROOF_C + 0.1, 'url(#silver)', ST)
rect(CL, CE - 0.1, EAVE, ROOF_C + 0.1, 'url(#roof)', 'plain')
rect(CL, CE - 0.1, EAVE, ROOF_C + 0.1, 'url(#silverroof)', ST)
rect(CL, CE - 0.1, NAVY[0], NAVY[1], 'url(#navy)', ST)
line(CL, EAVE, CE + 0.3, EAVE, '#000', 1.0, extra=' stroke-opacity="0.15"')
rect(CL, CE - 0.1, SKIRT, BOTTOM, '#595d62', ST)
rect(CL, CE - 0.1, SKIRT, BOTTOM, '#8d949c', 'plain')
line(CL, BOTTOM, CE, BOTTOM, '#000', 1.0, extra=' stroke-opacity="0.2"')
d.end()
# The end section's windows (171.webp; positions estimated).
for a, b in ((CE + 1.15, CE + 1.85), (CE + 2.15, CE + 2.95), (CE + 3.20, CE + 3.95)):
    rect(a, b, 2.42, 3.24, '#9aa0a6', rx=5)
    rect(a + 0.05, b - 0.05, 2.47, 3.19, 'url(#glass)', rx=4)
# End wall and gangway bellows between the vehicles; the coach's buffer.
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
