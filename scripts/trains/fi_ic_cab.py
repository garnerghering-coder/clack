"""VR Edo, the InterCity double-deck driving trailer (Finland, Transtech Otanmäki 2013-2017, 28601-28642), whole, cab
to the right, and the end of the next double-deck coach. docs/TRAIN_ART.md; style as x40.py / er1.py.

Class: the driving trailer is the Edo ("ohjausvaunu"), not the Edfs (an Edfs is a conductor/service coach with no
cab, fi.wikipedia "Edfs"). Push-pull with an Sr2 or Sr3 at the other end (fi.wikipedia "Edo (ohjausvaunu)").

Sources (retrieved 2026-10-24):
- vaunut.org photo 177045 (Kajaani, 2025-09-29, IC 65 "EDO edellä", 1390 x 700, https://vaunut.org/kuva/177045):
  the Edo side-on, cab right, in the white/grey/green livery. The main measuring photo, rectified (below).
- Garner's photos (2026-10-24): 106.png, a whole set side-on with the Edo leading (livery layout, the second car);
  101.png and 104.png (cab, 3/4). 105.png is an artist's rendering: not used for any measurement or livery detail.
- vaunut.org 169124 (Edo 28631, Lappeenranta 2024-06-06, 3/4): cab side window, door, roof cap, bogie, buffers.
- Commons, category "VR Class Edo": "Joensuu station 1" (2019, 28629 from a train window: the cab end and art panel).
- Škoda Group reference "Kaksikerroksiset ohjausvaunut" (https://www.skodagroup.com/fi/viite/kaksikerroksiset-ohjausvaunut):
  length 27 400 mm, width 3 200 mm, height above rail 5 200 mm, lower floor 550 mm above rail, bogies TB201.
- fi.wikipedia "Edo (ohjausvaunu)" (action=raw): Transtech, 42 built 2013-2017, 27 400 mm, broad gauge 1 524 mm.
Rectifying 177045: a homography fitted to the corners of the five lower-deck and six upper-deck windows (equal pitch
and size assumed; rms 0.37 px, max 0.96 px). Scale: the body taken as 26.25 m (27.4 m over buffers less about
0.6 m per buffer: estimate, as no source gives the body length). Check: the rail then comes out 5.17 m below the roof
against the 5.2 m height above rail (0.6%). Window pitch 1.90 m.
Measured off the rectified photo (metres back from the nose tip; h = metres below the roof):
- body 0-26.25 m; underside 4.89 between the bogies, 4.74 at the nose; bogie arches up to 4.41 from 1.78 to 5.30 and
  from 21.5 to 25.2 m; bogie centres 3.50 and 23.38 m (19.9 m apart), axles 2.5 m; rail 5.17
- nose (outline read every 0.4-0.7 m of height): roof level to 3.0 m, (2.16, 0.02) (1.50, 0.41) (1.02, 0.79)
  (0.66, 1.27) (0.45, 1.74) (0.29, 2.31) (0.16, 2.98) (0.10, 3.65) (0.02, 4.3) (0, 4.6); the roof cap's seam from
  (3.07, 0) down to (2.73, 0.74) and along (1.50, 0.84) (0.92, 1.17) (0.59, 1.55)
- upper deck windows 0.81-1.70: 19.50-18.90 | 18.16-16.86, 16.24-14.97, 14.33-13.03, 12.43-11.17, 10.52-9.26,
  8.62-7.36 | 5.84-5.23; lower deck windows 3.24-4.10: 18.16-16.88, 16.24-14.97, 14.33-13.07, 12.43-11.16,
  10.52-9.26, 8.62-8.07 (narrow); rear-end window 24.26-23.00, 2.49-3.36; cab side window 1.41-0.74, 2.14-2.84
- doors 19.71-18.70 and 7.76-6.76 m, 2.60-4.87 (to the lower body's bottom), windows 0.25-0.75 of the door width,
  3.01-3.86; rear-end equipment hatch 26.03-25.05, 2.39-4.00
- roof-side grilles 25.57-24.52, 24.45-23.33 (rear) and 3.95-2.86 (cab), 0.76-1.41
Livery `vr-fi` (VR InterCity, the white/grey/green scheme of photo 106 and 177045):
- light grey roof to 0.74, grey side to 1.80, a darker grey line 1.80-1.98, white below, grey lower body from 4.22
- green stripe 3.49-3.86 from 5.35 m to the nose (cab end) and 3.39-3.77 from 21.64 m to the rear end
- green band between the decks 2.60-2.98 from 17.6 to 8.73 m, both ends slanted as the panels
- green artwork panels round the doors, straight slanted sides: rear (19.88, 0.74) (16.16, 0.74) (18.83, 4.17)
  (21.92, 4.17); front (7.11, 0.74) (4.21, 0.74) (5.59, 4.17) (9.30, 4.17); lighter green in the top part to 1.75.
Estimated / unverified: the body length (above), the gangway (0.45 m), wheel diameter 0.92 m (not seen clearly;
no source), the second car's end (taken as the Edo's rear end: grey band, stripe; nothing else drawn on its 1.6 m).
Not drawn: the panels' artwork (forest, birds, lake), the VR logos and lettering, the cab front's windscreen (it is on
the front face, not seen side-on), the buffers and coupler (not measured side-on), the newer all-green 2025 livery.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

VR = 'vr-fi'
CAR, BODY, GANG, SHOW = 26.25, 4.89, 0.45, 1.6


class EdoDrawing(Drawing):
    """The kit's drawing with a view box that takes the wheels down to the rail."""

    def viewbox(self):
        return f'{self.VB_X:.0f} {self.ROOF - 8} {self.TIP + 8 - self.VB_X:.0f} {5.30 * self.M + 8:.0f}'


d = EdoDrawing(car_m=CAR, body_m=BODY, gangway_m=GANG, show_second_m=SHOW, liveries=[VR])
x, M, ROOF, BASE, TIP, REAR = d.x, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
S = d.SECOND_END


def Y(h):
    return ROOF + h * M


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def poly(pts, fill, only=None, extra=''):
    d.add(f'<path d="M{" L".join(P(m, h) for m, h in pts)} Z" fill="{fill}"{extra}/>', only)


def smooth(pts):
    Q = [(x(m), Y(h)) for m, h in pts]
    out = []
    for i in range(len(Q) - 1):
        p0, p1, p2, p3 = Q[max(i - 1, 0)], Q[i], Q[i + 1], Q[min(i + 2, len(Q) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return ' '.join(out)


d.gradient('vrgrey', ['#b9bec3', '#a7adb3'])
d.gradient('vrwhite', ['#f6f7f7', '#eceeef', '#e2e5e7'])
GREEN, LIGHT, SEAM, SKIRT, ROOFC = '#5fb43a', '#a9dc86', '#7f868c', '#7c8389', '#cfd3d6'
GLINE = '#8d949c'
ROOF_EDGE, SIDE_EDGE, SEAM_EDGE, SKIRT_TOP = 0.74, 1.80, 1.98, 4.22


def livery_bands(x0, x1, rear_stripe):
    """Paint for a stretch of body (drawing x from x0 to x1): roof, grey side, seam, skirt; the plain version keeps
    the roof and the grey lower body as metal greys too (they are unpainted on the real car: fittings, not livery)."""
    w = x1 - x0
    d.add(f'<rect x="{x0:.1f}" y="{ROOF - 4}" width="{w:.1f}" height="{BODY * M + 8:.1f}" fill="url(#body)"/>', 'plain')
    d.add(f'<rect x="{x0:.1f}" y="{ROOF - 4}" width="{w:.1f}" height="{BODY * M + 8:.1f}" fill="url(#vrwhite)"/>', VR)
    d.add(f'<rect x="{x0:.1f}" y="{ROOF - 4}" width="{w:.1f}" height="{ROOF_EDGE * M + 4:.1f}" fill="url(#roof)"/>', 'plain')
    d.add(f'<rect x="{x0:.1f}" y="{ROOF - 4}" width="{w:.1f}" height="{ROOF_EDGE * M + 4:.1f}" fill="{ROOFC}"/>', VR)
    d.add(f'<rect x="{x0:.1f}" y="{Y(ROOF_EDGE):.1f}" width="{w:.1f}" height="{(SIDE_EDGE - ROOF_EDGE) * M:.1f}" fill="url(#vrgrey)"/>', VR)
    d.add(f'<rect x="{x0:.1f}" y="{Y(SIDE_EDGE):.1f}" width="{w:.1f}" height="{(SEAM_EDGE - SIDE_EDGE) * M:.1f}" fill="{SEAM}"/>', VR)
    d.add(f'<rect x="{x0:.1f}" y="{Y(SKIRT_TOP):.1f}" width="{w:.1f}" height="{(BODY - SKIRT_TOP) * M + 4:.1f}" fill="{SKIRT}"/>', VR)
    d.add(f'<line x1="{x0:.1f}" y1="{Y(SEAM_EDGE):.1f}" x2="{x1:.1f}" y2="{Y(SEAM_EDGE):.1f}" stroke="{GLINE}" stroke-width="1"/>', 'plain')


# ---------------------------------------------------------------- second car (double-deck coach), its end only
d.clip('c2', f'M{d.VB_X - 10},{Y(4.95):.1f} V{ROOF} H{S - 8:.1f} Q{S},{ROOF} {S},{ROOF + 8} V{Y(4.95):.1f} Z')
d.group('c2')
livery_bands(d.VB_X - 10, S, True)
d.add(f'<rect x="{d.VB_X - 10}" y="{Y(3.39):.1f}" width="{S - d.VB_X + 10:.1f}" height="{0.38 * M:.1f}" fill="{GREEN}"/>', VR)
d.end()
B0 = CAR + GANG
rect(B0 + 2, B0 + 0.3, 4.41, 4.95, '#2a2f36')
d.bogie(x(B0 + 2.9), axle_m=2.5, wheel_m=0.92, top=Y(4.41), wc=Y(4.74))
# Gangway.
rect(CAR, B0, 0.35, 4.6, '#2b3037')
for i in range(1, 4):
    m = CAR + i * GANG / 4
    d.add(f'<line x1="{x(m):.1f}" y1="{Y(0.4):.1f}" x2="{x(m):.1f}" y2="{Y(4.55):.1f}" stroke="#41474f" stroke-width="1.5"/>')

# ---------------------------------------------------------------- running gear behind the body
rect(21.4, 5.4, 4.40, 4.95, '#2a2f36', rx=2)
for c in (23.38, 3.50):
    d.bogie(x(c), axle_m=2.5, wheel_m=0.92, top=Y(4.41), wc=Y(4.74))

# ---------------------------------------------------------------- the Edo's body
NOSE = [(3.0, 0.0), (2.16, 0.02), (1.50, 0.41), (1.02, 0.79), (0.66, 1.27), (0.45, 1.74), (0.29, 2.31), (0.16, 2.98),
        (0.10, 3.65), (0.02, 4.30), (0.0, 4.60), (0.03, 4.74)]
r = 0.2 * M
outline = (
    f'M{REAR},{Y(4.95):.1f} V{ROOF + r:.1f} Q{REAR},{ROOF} {REAR + r:.1f},{ROOF} L{P(3.0, 0.0)} ' + smooth(NOSE) + ' '
    f'L{P(1.60, 4.74)} L{P(1.78, 4.41)} L{P(5.30, 4.41)} L{P(5.45, 4.89)} L{P(21.35, 4.89)} L{P(21.5, 4.41)} '
    f'L{P(25.2, 4.41)} L{P(25.35, 4.95)} Z'
)
d.clip('c1', outline)
d.group('c1')
livery_bands(REAR, TIP + 10, False)
# Green artwork panels round the doors (light green top part), the band between the decks and the lower stripes.
for pts in (((19.88, ROOF_EDGE), (16.16, ROOF_EDGE), (18.83, 4.17), (21.92, 4.17)),
            ((7.11, ROOF_EDGE), (4.21, ROOF_EDGE), (5.59, 4.17), (9.30, 4.17))):
    poly(pts, GREEN, VR)
    (a, t), (b, _), (c, bot), (e, _) = pts
    k = (1.75 - t) / (bot - t)
    poly([(a, t), (b, t), (b + (c - b) * k, 1.75), (a + (e - a) * k, 1.75)], LIGHT, VR)
poly([(17.6 + 0.0, 2.60), (8.73 + 0.29, 2.60), (8.73, 2.98), (17.6 + 0.29, 2.98)], GREEN, VR)
poly([(5.35, 3.49), (-0.3, 3.49), (-0.3, 3.86), (5.35 + 0.29, 3.86)], GREEN, VR)
poly([(21.64, 3.39), (CAR + 0.1, 3.39), (CAR + 0.1, 3.77), (21.64 + 0.29, 3.77)], GREEN, VR)
# Roof cap seam at the cab.
d.add(f'<path d="M{P(3.07, 0.0)} Q{P(2.95, 0.70)} {P(2.73, 0.74)} L{P(1.50, 0.84)} Q{P(1.10, 1.0)} {P(0.92, 1.17)} L{P(0.59, 1.55)}" '
      f'fill="none" stroke="#6d747b" stroke-width="1.2"/>')
d.end()

# Windows: upper deck, lower deck, rear-end window, cab side window.
WF = '#0b0d10'
for a, b in ((19.50, 18.90), (18.16, 16.86), (16.24, 14.97), (14.33, 13.03), (12.43, 11.17), (10.52, 9.26), (8.62, 7.36), (5.84, 5.23)):
    rect(a, b, 0.81, 1.70, WF, rx=4)
    rect(a - 0.05, b + 0.05, 0.86, 1.65, 'url(#glass)', rx=3)
for a, b in ((18.16, 16.88), (16.24, 14.97), (14.33, 13.07), (12.43, 11.16), (10.52, 9.26), (8.62, 8.07)):
    rect(a, b, 3.24, 4.10, WF, rx=4)
    rect(a - 0.05, b + 0.05, 3.29, 4.05, 'url(#glass)', rx=3)
rect(24.26, 23.00, 2.49, 3.36, WF, rx=4)
rect(24.21, 23.05, 2.54, 3.31, 'url(#glass)', rx=3)
d.add(f'<path d="M{P(1.41, 2.20)} Q{P(1.41, 2.14)} {P(1.35, 2.14)} L{P(0.80, 2.14)} Q{P(0.74, 2.14)} {P(0.74, 2.20)} '
      f'L{P(0.74, 2.84)} L{P(1.30, 2.76)} Q{P(1.41, 2.74)} {P(1.41, 2.66)} Z" fill="url(#glass)" stroke="{WF}" stroke-width="2"/>')


def door(front, rear):
    x0, x1 = x(rear), x(front)
    w = x1 - x0
    rect(front, rear, 2.60, 4.87, 'url(#steel)', rx=3)
    d.door(x0, w, 2.60 / BODY, 4.87 / BODY, win=(0.25, 0.75, 3.01 / BODY, 3.86 / BODY), stroke='#5d646c')


# The kit's door() takes heights as fractions of the body; pass them so.
door(18.70, 19.71)
door(6.76, 7.76)
# Rear-end equipment hatch, roof-side grilles.
rect(26.03, 25.05, 2.39, 4.00, 'none', rx=2, extra=f' stroke="{GLINE}" stroke-width="1.2"')
for a, b in ((25.57, 24.52), (24.45, 23.33), (3.95, 2.86)):
    rect(a, b, 0.76, 1.41, '#4a5058', rx=1.5)
    n = int((a - b) / 0.09)
    for i in range(1, n):
        m = b + i * (a - b) / n
        d.add(f'<line x1="{x(m):.1f}" y1="{Y(0.80):.1f}" x2="{x(m):.1f}" y2="{Y(1.37):.1f}" stroke="#8a929b" stroke-width="0.8"/>')

COMMENT = '// VR Edo InterCity double-deck driving trailer, side view to scale. Generated by scripts/trains/fi_ic_cab.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'FiIcCab.tsx')
if __name__ == '__main__':
    main(d, 'FiIcCabSide', COMMENT, OUT)
