"""Siemens Desiro Classic (2-car articulated DMU; DSB MQ, Nordjyske Jernbaner DM 541-547/571-577, Arriva AR 3065-3072
/ 4083-4090, Midtjyske MQ 4111-4114): the A car whole, cab to the right, the bellows and the start of the B car behind
it. docs/TRAIN_ART.md; style as fi_dm12.py.

Liveries: `nordjyske` (Nordjyske Jernbaner: ultramarine blue body; a grey cap: the roof edge along the car and a grey
rim down the nose into the windscreen surround; grey skirt; dark window frames; a yellow strip on the door leaves),
`arriva` (the ex-DSB MQs as Arriva/GoCollective ran them: white body, navy window band whose front curves down into
the windscreen, the same grey cap and rim, grey skirt; owner's 193 and 192, Arriva logo not drawn), plus `plain`.
`arriva`, not `vores-tog`: DSB took over operation in Midt- og Vestjylland and on Svendborgbanen on 1 September 2026
(Transport Ministry press release, reported by Altinget, "DSB overtager Gocollectives togtrafik"), but no source or
dated photo shows what the Desiros wear since; 193 and 192 are undated and carry Arriva's logo. The paint is DSB's MQ
scheme (the 2012 Commons panorama shows the same white/navy/grey layout) kept by Arriva.
Not drawn: the thin light-blue and gold swirl artwork on the NJ bodysides. It differs from unit to unit (each unit is
named after a local artist) and no photo shows one unit's whole side, so it can't be traced honestly.
No Midtjyske livery (MQ 4111-4114): no photo of them in their current paint.
The Czech Arriva photos (owner's 172/173) were used for the body only; their livery is not Danish and is not drawn.

Sources (retrieved 2026-10-28):
- de.wikipedia "Siemens Desiro Classic" and "DSB MQ" (action=raw): 41 700 mm over couplers, width 2 830, floor 575 mm
  at the doors, B'(2)'B' (a motor bogie under each cab, a Jakobs bogie at the joint), 60 % low floor; NJJ bought seven
  units in 2004-05, dark blue, named after local artists; DSB's 20 MQ went to Arriva (16) and Midtjyske (4) in 2020.
- Owner's 173 (Arriva CZ, near side-on, 660 px): the layout. Rectified with a homography of the side plane fitted on
  both cars' door frames (8 points, residuals <= 0.03 m); the B cab's nose is then side-on. In that frame the joint is
  20.41 and the B nose (its lower front face) 41.73, so the A nose is at -0.91 (the unit is symmetric). Metres here =
  (that frame + 0.91) x 0.966, which puts the joint 20.60 m behind the nose (41.7 m over couplers less an estimated
  0.25 m of coupler at each end); heights are scaled by the same factor.
- Commons "DSB MQ 4912, Odense, Denmark, pano ve.2 (7420679916).jpg" (3840 x 994, a stitched side-on panorama, DSB
  livery): heights, the nose outline and the underside, at 94.1 px/m (doors 964.5 px from the joint = 10.25 m), rail at
  y 648 (door sill 0.60 m, ballast top 665). Its stitch compresses the ends, so it is not used for lengths ahead of the
  door (it puts the first window 0.2 m further forward than 173).
- Owner's 176 (NJ, cab car at a platform, 746 px): the cab side, rectified on window 1 (2.46), window 3 (7.50) and the
  door frame (9.45-11.25), residuals <= 0.09 m. Owner's 172 (Arriva CZ 642 837, sharp 3/4 front), 174 (NJ, Hirtshals,
  3/4 front), 175 (NJ, whole unit) and 177 (NJ, 2007): the front, the window shapes and the NJ paint. Colours sampled in
  daylight: body #1f3e96 (176 #183896-#1f4299, 175 #1e3980), grey cap #a0a9ba (175), skirt #444a4f-#736c61.
- Owner's 193 (an Arriva Desiro cab at København H, near side-on, 746 px; night, so colours from the panorama: navy
  #1e2a44, skirt #69695c): rectified on the cab window, the triangular window's rear edge and the seam (residuals
  <= 0.01 m). It confirms the cab side (cab window 0.88-1.38, triangle rear edge 0.64, top 2.73, its foot at the nose),
  the grey roof edge 3.50-3.62 running down the nose into the windscreen, and gives the navy band: 2.16-3.16, its front
  edge (1.20, 3.16) (0.68, 3.02) (0.32, 2.72) (0.04, 2.40) to the nose at 2.16. Behind the door the band runs 1.29-3.22
  (panorama). 193 puts the skirt top about 0.1 m higher than drawn (1.24); the lower side curves in (tumblehome), so
  the side-plane rectification is least reliable there.
Measured (m = metres back from the A nose tip; h = metres above rail):
- body: roof crown 3.68; roof boxes 3.21-6.81 and 12.56-16.08 (to 3.83), a lower one 6.81-8.65 (3.76). Underside 0.51
  from the nose to 7.8 m (high-floor end), stepping to 0.40 by 8.0 (low floor); raised to 1.02 over the motor bogie
  (1.45-4.69, centre 3.07) and to 0.81 over the Jakobs bogie (18.37 to 22.65 on the B car). Car end 20.28, bellows
  20.28-20.86, joint 20.60. Cab module seam 1.72 (0.54 m behind the cab window: 176, 193).
- nose outline (panorama, px from the tip at 94.1 px/m): (2.69, 3.67) (1.89, 3.57) (1.36, 3.38) (0.94, 3.15)
  (0.56, 2.85) (0.30, 2.53) (0.11, 2.21) (0.03, 1.89) (0.0, 1.57) (0.03, 1.25) (0.09, 1.09) (0.14, 0.78) (0.30, 0.60)
  (0.56, 0.51). 173's B nose agrees above 2.9 m within 0.05 m ((0.99, 3.16) (1.28, 3.35) (1.67, 3.50) (2.15, 3.60)); below
  that it is too blurred against the background to read. The windscreen runs up the raked part from the destination
  display (1.89-2.21) to the cap at 3.15; the headlight band below it, 1.57-1.89 (172's front, 160 px/m).
- windows (frames): high-floor end, h 2.19-3.15: 2.46-3.95, 4.24-5.69, 6.06-7.50, 7.81-8.38 (narrow). Low-floor centre,
  h 1.36-3.17: 11.64-12.84, 13.18-14.60, 16.73-18.16, 18.49-19.67 (14.60-16.73 blank: the toilet); B car's first
  21.54-22.72. Door frame 9.45-11.25, h 0.60-3.26, two leaves, leaf windows 1.46-3.08. DSB's panorama and 172 show a
  second, very narrow window just ahead of the door; 176 (NJ) has none there, so it is not drawn.
- cab, revised 2026-10-28 after review (the owner: the front read wrong): drawn from the ratios in 176, 175 and 193
  relative to the tall cab window (0.50 m x 0.81 m), which the curved nose does not distort: the triangle about as wide
  as that window and 0.74 of its height (176: 1.5 x / 0.72, 193: 1.6 x / 0.67, both inflated by perspective), the
  windscreen a 0.20 m dark band up the raked nose from 1.80 m to the cap at 3.14 m (193), the slope from the roof to
  the tip about the length of the two cab windows. With the overall length kept, the cab window is 1.12-1.62 (seam 2.05,
  first window 2.55-3.95) and the nose outline (0.0, 1.60) (0.06, 2.05) (0.17, 2.30) (0.40, 2.58) (0.68, 2.88) (1.00,
  3.14) (1.40, 3.37) (1.90, 3.55) (2.60, 3.66) (lower part as before). This puts the cab window 0.4 m further back than
  the panorama and 173 measure, outside their stated error: unverified, chosen for the look of 175/176/193.
  Superseded measurement: the tall cab window 0.68-1.18 (panorama 0.62-1.10, 173's A cab 0.71-1.23; 176 rectified 0.88-1.38), h 2.20-3.01,
  its top front corner cut along the band curve (193); the raked triangular side window 0.24 m ahead of it (176, 193:
  rear edge 0.44, top 2.73), its front edge running down parallel to the nose to the foot at 2.21. Side-plane
  rectifications of 176 and 193 put the triangle's foot and the windscreen well forward of the tip: those parts lie on
  the curved nose, which the rectification pushes forward, so the nose outline is the side-on panorama's, which 173's
  B nose confirms.
- band front (DSB/Arriva scheme, panorama, the same paint as 193): the navy band's top curves down from (1.79, 3.18)
  through (1.09, 3.08) (0.56, 2.84) into the windscreen.
- NJ paint (174-176): grey from 3.48 m up along the car, following the nose down as a 0.13 m rim into the windscreen
  surround; the headlight band grey; skirt grey from 1.10 (ahead of the door) / 0.83 (behind it); doors blue with dark
  frames; yellow strip 0.80-0.98 across the leaves (176: y 231-239 on a door 129-248).
Estimated / unverified: the coupler length (0.25 m) and so the overall scale (+-2 %); the window positions ahead of the
door (+-0.3 m: 173 is low resolution and the panorama is compressed there); bogie wheelbases (2.2 m motor, 2.6 m Jakobs)
and wheels (0.77 m); the engine box under the high-floor end; whether the NJ units still wear this livery in 2026 (the
newest NJ photo here is undated).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

NJ, AR = 'nordjyske', 'arriva'
CAR, GANG, SHOW = 20.28, 0.58, 1.60
TOP, BASE = 3.68, 0.40
END_B = CAR + GANG + SHOW


class DesiroDrawing(Drawing):
    """Heights in metres above rail; the view box takes the A car, the bellows, the start of the B car and the coupler."""

    def Y(self, h):
        return self.ROOF + (TOP - h) * self.M

    def viewbox(self):
        left, right, top = self.x(END_B), self.x(-0.50), self.Y(3.95)
        return f'{left:.0f} {top:.0f} {right - left:.0f} {self.Y(-0.04) - top:.0f}'


d = DesiroDrawing(car_m=CAR, body_m=TOP - BASE, show_second_m=SHOW, gangway_m=GANG, liveries=[NJ, AR])
x, Y, M = d.x, d.Y, d.M
d.gradient('equip', ['#d3d7dc', '#aab1b8'])
d.gradient('njblue', ['#2a4aa6', '#1f3e96', '#1a3684'])
BLUE, CAP, SKIRT_NJ, YEL, FRAME = 'url(#njblue)', '#9ea8b5', '#5d646b', '#e8b62a', '#2a2f36'
NAVY = '#22304d'
CAPPED = (NJ, AR)
SKIRT, DARK = '#6b737c', '#2a2f36'


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def poly(pts, fill, only=None, extra=''):
    d.add(f'<path d="M{" L".join(P(m, h) for m, h in pts)} Z" fill="{fill}"{extra}/>', only)


def smooth(pts):
    """Catmull-Rom through (m, h) points -> SVG path (M then cubic segments)."""
    Q = [(x(m), Y(h)) for m, h in pts]
    out = []
    for i in range(len(Q) - 1):
        p0, p1, p2, p3 = Q[max(i - 1, 0)], Q[i], Q[i + 1], Q[min(i + 2, len(Q) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return f'M{Q[0][0]:.1f},{Q[0][1]:.1f} ' + ' '.join(out)


def tail(path):
    return path[path.index(' ') + 1:]


def inset(pts, t):
    """The outline moved t metres into the body (along each point's normal, the body lying behind and below)."""
    out = []
    for i, (m, h) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        dm, dh = b[0] - a[0], b[1] - a[1]
        n = (dm * dm + dh * dh) ** 0.5 or 1
        nm, nh = -dh / n, dm / n  # left normal of the direction of travel
        if nm < 0:
            nm, nh = -nm, -nh
        out.append((m + nm * t, h + nh * t))
    return out


# Nose, bottom to roof (panorama; see the docstring).
NOSE = [(0.56, 0.51), (0.30, 0.60), (0.14, 0.80), (0.08, 1.08), (0.03, 1.30), (0.0, 1.60), (0.01, 1.80), (0.06, 2.05),
        (0.17, 2.30), (0.40, 2.58), (0.68, 2.88), (1.00, 3.14), (1.40, 3.37), (1.90, 3.55), (2.60, 3.66), (3.20, TOP)]
UPPER = NOSE[6:]  # windscreen and cab roof, from the windscreen's foot (1.80) up

# ---------------------------------------------------------------- running gear and underframe (behind the body)
WC = Y(0.385)
d.bogie(x(3.07), axle_m=2.2, wheel_m=0.77, top=Y(0.95), wc=WC)
d.bogie(x(20.60), axle_m=2.6, wheel_m=0.77, top=Y(0.78), wc=WC)
rect(4.95, 7.60, 0.52, 0.30, DARK, rx=2, extra=' stroke="#3f464f" stroke-width="1"')
# Coupler (estimated), in the recess under the headlight band.
rect(0.30, -0.25, 0.98, 0.82, '#5a6169')
rect(-0.25, -0.37, 1.02, 0.78, '#3b4148', rx=2)

# ---------------------------------------------------------------- bellows and the B car
rect(CAR - 0.05, CAR + GANG + 0.05, 0.86, TOP - 0.10, '#2b3037')
for i in range(6):
    m = CAR + 0.06 + i * (GANG - 0.12) / 5
    d.add(f'<line x1="{x(m):.1f}" y1="{Y(TOP - 0.14):.1f}" x2="{x(m):.1f}" y2="{Y(0.90):.1f}" stroke="#4a515a" stroke-width="2"/>')
B0 = CAR + GANG
boutline = (f'M{P(B0, 0.81)} L{P(B0, TOP - 0.12)} Q{P(B0, TOP)} {P(B0 + 0.12, TOP)} L{P(END_B + 0.2, TOP)} '
            f'L{P(END_B + 0.2, BASE)} L{P(22.90, BASE)} Q{P(22.65, BASE)} {P(22.65, 0.60)} L{P(22.65, 0.81)} Z')
d.clip('bcar', boutline)
d.group('bcar')
rect(B0 - 0.1, END_B + 0.3, BASE - 0.05, TOP + 0.1, 'url(#body)')
rect(B0 - 0.1, END_B + 0.3, BASE - 0.05, TOP + 0.1, BLUE, NJ)
rect(B0 - 0.1, END_B + 0.3, 3.48, TOP + 0.1, CAP, CAPPED)
rect(B0 - 0.1, END_B + 0.3, 1.29, 3.18, NAVY, AR)
rect(B0 - 0.1, END_B + 0.3, BASE - 0.05, 0.83, SKIRT)
rect(B0 - 0.1, END_B + 0.3, BASE - 0.05, 0.83, SKIRT_NJ, NJ)
rect(22.72, 21.54, 3.17, 1.36, FRAME, rx=5)
rect(22.72 - 0.06, 21.54 + 0.06, 3.11, 1.42, 'url(#glass)', rx=4)
d.end()
d.add(f'<path d="{boutline}" fill="none" stroke="#000" stroke-opacity="0.22" stroke-width="1.2"/>')

# ---------------------------------------------------------------- A car body
outline = (f'M{P(CAR, TOP - 0.15)} L{P(CAR, 0.81)} '
           + f'L{P(18.62, 0.81)} Q{P(18.37, 0.81)} {P(18.37, 0.60)} L{P(18.37, 0.50)} Q{P(18.37, BASE)} {P(18.17, BASE)} '
           + f'L{P(8.00, BASE)} L{P(7.80, 0.51)} L{P(4.69, 0.51)} L{P(4.69, 0.82)} Q{P(4.69, 1.02)} {P(4.49, 1.02)} '
           + f'L{P(1.65, 1.02)} Q{P(1.45, 1.02)} {P(1.45, 0.82)} L{P(1.45, 0.51)} '
           + tail(smooth(NOSE)) + f' L{P(CAR - 0.15, TOP)} Q{P(CAR, TOP)} {P(CAR, TOP - 0.15)} Z')
d.clip('carbody', outline)
d.group('carbody')
rect(CAR + 0.1, -0.1, BASE - 0.05, TOP + 0.2, 'url(#body)')
rect(CAR + 0.1, -0.1, BASE - 0.05, TOP + 0.2, BLUE, NJ)
# Lower panel: up to 1.10 ahead of the door, 0.83 behind it (stepping down at the door).
skirt = [(-0.3, 1.10), (8.95, 1.10), (9.45, 0.83), (CAR + 0.1, 0.83), (CAR + 0.1, 0.3), (-0.3, 0.3)]
poly(skirt, SKIRT)
poly(skirt, SKIRT_NJ, NJ)
# NJ grey cap: along the car from 3.48 up; on the cab a 0.13 m rim following the nose down to the windscreen.
RIM = [p for p in UPPER if p[1] >= 2.88]
inner = inset(RIM, 0.13)
inner = [p for p in inner if p[1] < 3.48]
cap = (f'M{P(-0.3, 2.85)} L{P(*RIM[0])} ' + tail(smooth(RIM)) + f' L{P(CAR + 0.1, TOP + 0.2)} L{P(CAR + 0.1, 3.48)} '
       + f'L{P(2.2, 3.48)} Q{P(1.75, 3.48)} {P(*inner[-1])} ' + tail(smooth(list(reversed(inner)))) + ' Z')
d.add(f'<path d="{cap}" fill="{CAP}"/>', CAPPED)
# Arriva: the navy window band, 2.16-3.18 on the high-floor end and 1.29-3.18 behind the door, its front a curve from the
# band top at 1.79 m down to the nose (panorama, 193), where it meets the windscreen.
BAND_FRONT = [(2.10, 3.18), (1.55, 3.10), (1.20, 2.97), (0.95, 2.80), (0.70, 2.50), (0.50, 2.16)]
band = (f'M{P(CAR + 0.1, 3.18)} L{P(*BAND_FRONT[0])} ' + tail(smooth(BAND_FRONT))
        + f' L{P(9.45, 2.16)} L{P(9.45, 1.29)} L{P(CAR + 0.1, 1.29)} Z')
d.add(f'<path d="{band}" fill="{NAVY}"/>', AR)
d.end()

# ---------------------------------------------------------------- front: windscreen up the raked nose, headlight band
d.group('carbody')
WS = [p for p in UPPER if p[1] <= 3.15]  # the windscreen, from its foot (1.80, display included) to the cap (3.14)
ws_in = inset(WS, 0.20)
screen = smooth(WS) + f' L{P(*ws_in[-1])} ' + tail(smooth(list(reversed(ws_in)))) + ' Z'
d.add(f'<path d="{screen}" fill="url(#glass)"/>')
d.add(f'<line x1="{x(0.0):.1f}" y1="{Y(2.06):.1f}" x2="{x(0.26):.1f}" y2="{Y(2.06):.1f}" stroke="#0b0d10" stroke-width="1.5"/>')
rect(-0.2, 0.16, 1.80, 1.55, '#b9c0c7')
rect(-0.2, 0.16, 1.80, 1.55, CAP, NJ)
d.add(f'<circle cx="{x(0.07):.1f}" cy="{Y(1.67):.1f}" r="3" fill="#f4f1e4" stroke="#6b737c" stroke-width="0.8"/>')
d.end()
d.add(f'<path d="{outline}" fill="none" stroke="#000" stroke-opacity="0.22" stroke-width="1.2"/>')


# ---------------------------------------------------------------- windows, door
def window(m0, m1, h0, h1, r=5):
    rect(m1, m0, h1, h0, FRAME, rx=r)
    rect(m1 - 0.06, m0 + 0.06, h1 - 0.06, h0 + 0.06, 'url(#glass)', rx=r - 1)


for a, b in ((2.55, 3.95), (4.24, 5.69), (6.06, 7.50), (7.81, 8.38)):
    window(a, b, 2.19, 3.15)
for a, b in ((11.64, 12.84), (13.18, 14.60), (16.73, 18.16), (18.49, 19.67)):
    window(a, b, 1.36, 3.17)
# Cab: the tall cab window, and the raked triangular side window ahead of it, its front edge parallel to the nose.
d.add(f'<path d="M{P(1.62, 2.26)} L{P(1.62, 2.95)} Q{P(1.62, 3.01)} {P(1.56, 3.01)} L{P(1.28, 3.01)} L{P(1.12, 2.90)} '
      f'L{P(1.12, 2.26)} Q{P(1.12, 2.20)} {P(1.18, 2.20)} L{P(1.56, 2.20)} Q{P(1.62, 2.20)} {P(1.62, 2.26)} Z" fill="{FRAME}"/>')
d.add(f'<path d="M{P(1.56, 2.26)} L{P(1.56, 2.95)} L{P(1.30, 2.95)} L{P(1.18, 2.87)} L{P(1.18, 2.26)} Z" fill="url(#glass)"/>')
# The triangle: rear edge 0.20 ahead of the cab window, pointed top at 2.80, front edge parallel to the windscreen.
d.add(f'<path d="M{P(0.92, 2.20)} L{P(0.92, 2.80)} L{P(0.89, 2.80)} L{P(0.42, 2.20)} Z" fill="{FRAME}"/>')
d.add(f'<path d="M{P(0.87, 2.25)} L{P(0.87, 2.70)} L{P(0.52, 2.25)} Z" fill="url(#glass)"/>')
# Door: two leaves with windows; NJ's yellow strip across them.
D0, D1 = 9.45, 11.25
DM = (D0 + D1) / 2
rect(D1, D0, 3.26, 0.60, '#c9ced4')
rect(D1, D0, 3.26, 0.60, BLUE, NJ)
rect(D1 - 0.02, D0 + 0.02, 0.98, 0.80, YEL, NJ)
rect(D1, D0, 3.26, 0.60, 'none', rx=3, extra=f' stroke="{FRAME}" stroke-width="2"')
d.add(f'<line x1="{x(DM):.1f}" y1="{Y(3.24):.1f}" x2="{x(DM):.1f}" y2="{Y(0.62):.1f}" stroke="{FRAME}" stroke-width="1.6"/>')
for a, b in ((D0 + 0.14, DM - 0.10), (DM + 0.10, D1 - 0.14)):
    rect(b, a, 3.08, 1.46, 'url(#glass)', rx=5, extra=' stroke="#0b0d10" stroke-width="2"')
# Cab module seam.
d.add(f'<line x1="{x(2.05):.1f}" y1="{Y(TOP - 0.05):.1f}" x2="{x(2.05):.1f}" y2="{Y(1.06):.1f}" stroke="#000" stroke-opacity="0.25" stroke-width="1"/>')

# ---------------------------------------------------------------- roof equipment
EQ = ' stroke="#8d949c" stroke-width="1"'
for a, b, h in ((6.81, 3.21, 3.83), (8.65, 6.81, 3.76), (16.08, 12.56, 3.83)):
    rect(a, b, TOP - 0.02, h, 'url(#equip)', rx=3, extra=EQ)

if __name__ == '__main__':
    main(d)
