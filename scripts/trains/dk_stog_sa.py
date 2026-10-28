"""DSB S-tog litra SA (LHB/Alstom, Adtranz/Bombardier, 1996-2006; Copenhagen S-bane): the cab car whole, cab to the
right, and the start of the next car of the articulated unit behind it. docs/TRAIN_ART.md; style as sl_c10.py.

Liveries: `dsb` (the refurbished look: red body, a dark grey band through the windows from the cab module's seam to
the car end, broken by the door; white door leaves with dark windows), `dsb-old` (all red, red doors, as SA 9197 in
July 2024), plus `plain`.

Both liveries are in service in 2026: the refurbishment that brings the new look started in 2024 and DSB plans the
whole fleet by 2028 (DSB press release "S-togene får nye farver på væggene og ombetrukket sæderne", February 2024: 32
sets in 2024, the rest by 2028; TV2 Kosmopol "Se forvandlingen: S-tog får helt nyt look": doors in a new colour, dark
framed windows). Both seen through search-result summaries only (dsb.dk and tv2kosmopol.dk were not reachable from
here), so the timeline is unverified.

SE (the 4-car version) has the same cab car and car body, so this drawing serves SA and SE alike. The 8-car / 4-car
make-up, the builders and "single axle bogies controlled by hydraulic cylinders ... covered by panels" in service:
FUNET Railway Photography Archive, Denmark S-tog page (https://ftp.funet.fi/pub/pics/railways/Denmark/s-train/,
retrieved 2026-10-28). Length 83.78 m over the 8 cars: unverified (from memory; a search summary gives 84.2 m).

Traced from (saved in the scratchpad, dk_stog/ref/):
- FUNET "dk-stog-sa9197-hundige-040724-full.jpg" (SA 9197 at Hundige, 2024-07-04, photo Ilkka Siissalo, 5184x3888):
  the cab car nearly side-on from ahead and to the left, all red. Read in a 1944 px wide copy (2.667 full px per px):
  the roof's crown line and the red side's bottom edge meet at u = -871, so along the side s = K (1432 - u)/(u + 871)
  metres back from the cab module's seam (u 1432); heights from the crown line and the rail line through the same
  point, the crown taken as 3.85 m above the rail (unverified). K = 15.9 makes 8 cars 83.78 m from the two joints in the
  photo (u 430 and 110), so the cab car reads 14.2 m and a middle car 9.2 m (+-0.6 m: the far joint is hard to read).
- FUNET "dk-stog-4thgen-koege-110713-pic2-full.jpg" (SA 9173, Køge 2011) and "...-koege-110713-full.jpg" (SA 9157):
  the front, the windscreen's black surround, the anticlimbers and coupler.
- Owner's photos (2026-10-28, in the conversation only): SA 8132 in the new livery (band from just behind the front,
  the cab side window inside it, white doors), SA 9150 (all red).
Measured (metres back from the nose: the red lower front, 1.98 m ahead of the seam; heights above the rail):
- nose profile: crown to 1.75, (1.38, 3.71), (0.78, 3.30), (0.61, 2.89), (0.43, 2.25), (0.27, 1.63), windscreen foot
  (0.15, 1.40); red lower front to 0.84, dark bumper to 0.35; the windscreen's near edge (1.38, 3.71) to (0.61, 1.48):
  the glass and its black surround between it and the profile. Coupler 0.80-1.10 high, 0.15 m proud of the bumper.
- red body to 0.80; dark grey strip to 0.62; darker panels over the running gear to 0.30, open round the wheel.
- seam 1.98; cab door 2.13-3.11 (1.01-3.15), its window 2.21-2.97 (2.19-3.06), a gutter over it at 3.24;
  windows 3.89-5.68, 6.02-7.73 (1.66-2.80); door 7.93-10.23 (1.00-3.15; leaf windows 8.26-8.92 and 9.36-10.00,
  1.68-2.71); windows 10.56-12.12, 12.40-14.01; joint 14.23-14.53; next car's first window from 14.89.
- running gear: a single axle under the cab car at 3.35 (its wheel shows below the panels), one under each joint.
Estimated, unverified: the crown height (sets every height); K and so the car's length; the band's top and bottom
(1.55-3.15, from the owner's 8132 by eye); the wheels' size (0.80 m); the coupler's shape.
Not drawn: the DSB logo and wordmark, numbers, the pram/bike/wheelchair pictograms, the line letter and destination
displays, the pantograph (on another car), the wipers, the hydraulic gear behind the panels.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

NEW, OLD = 'dsb', 'dsb-old'
CAR, GANG, SHOW = 14.23, 0.3, 1.6
CROWN, RED_B, STRIP_B, SKIRT = 3.85, 0.80, 0.62, 0.30
BAND_T, BAND_B = 3.15, 1.55
WIN_T, WIN_B = 2.80, 1.66
DOOR_T, DOOR_B = 3.15, 1.00
SEAM = 1.98


class SaDrawing(Drawing):
    def viewbox(self):
        right = self.x(-0.35)
        top = Y(CROWN + 0.15)
        return f'{self.VB_X:.0f} {top:.0f} {right - self.VB_X:.0f} {Y(-0.08) - top:.0f}'


def Y(h):
    """Height above the rail (m) to drawing y."""
    return d.ROOF + (CROWN - h) * d.M


d = SaDrawing(car_m=CAR, body_m=CROWN - SKIRT, gangway_m=GANG, show_second_m=SHOW, liveries=[NEW, OLD])
x, M, S = d.x, d.M, d.SECOND_END


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


d.gradient('red', ['#a8161f', '#cf2531', '#c8202c', '#ad1823'])
d.gradient('strip', ['#4a4f56', '#40454c'])
d.gradient('skirt', ['#33373d', '#2a2e33'])
d.gradient('dwhite', ['#f6f7f7', '#eceeef', '#d9dcdf'])
RED = (NEW, OLD)
BAND, EQUIP, LINE = '#33373d', '#2a2f36', '#7e1219'


def livery(m0, m1, band=()):
    """The body's paint between m0 and m1 (inside a clip); band: (from, to) stretches of the new livery's band."""
    rect(m0, m1, CROWN + 0.1, RED_B, 'url(#body)', 'plain')
    rect(m0, m1, RED_B, SKIRT - 0.1, '#7d858d', 'plain')
    rect(m0, m1, CROWN + 0.1, RED_B, 'url(#red)', RED)
    rect(m0, m1, RED_B, STRIP_B, 'url(#strip)', RED)
    rect(m0, m1, STRIP_B, SKIRT - 0.1, 'url(#skirt)', RED)
    rect(m0, m1, STRIP_B + 0.01, STRIP_B - 0.01, '#1f2226')
    for a, b in band:
        rect(a, b, BAND_T, BAND_B, BAND, NEW)


def window(a, b, top=WIN_T, bottom=WIN_B):
    rect(a, b, top, bottom, '#0b0d10', rx=6)
    rect(a - 0.06, b + 0.06, top - 0.06, bottom + 0.06, 'url(#glass)', rx=5)


# ---------------------------------------------------------------- the next car's front end (the sliver)
B0 = CAR + GANG
R2 = 0.35 * M
d.clip('c2', f'M{d.VB_X - 10},{Y(SKIRT):.1f} V{Y(CROWN):.1f} H{S - R2:.1f} Q{S},{Y(CROWN):.1f} {S},{Y(CROWN) + R2:.1f} V{Y(SKIRT):.1f} Z')
d.group('c2')
livery(B0 + 3, B0 - 0.1, band=((B0 + 3, B0 + 0.1),))
d.end()
window(B0 + 2.0, B0 + 0.36)
# The joint: a dark bellows between the car bodies.
rect(CAR - 0.05, B0 + 0.05, 3.70, RED_B, '#2b3037')
for i in range(1, 4):
    m = CAR + i * GANG / 4
    d.add(f'<line x1="{x(m):.1f}" y1="{Y(3.66):.1f}" x2="{x(m):.1f}" y2="{Y(RED_B):.1f}" stroke="#41474f" stroke-width="1.4"/>')

# ---------------------------------------------------------------- running gear (single axles; drawn first, the panels cover them)
WR = 0.40


def wheel(a):
    d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WR):.1f}" r="{WR * M - 1:.1f}" fill="#1b1f25" stroke="#727b86" stroke-width="2"/>')
    d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WR):.1f}" r="4" fill="#6d7681"/>')
    rect(a - 0.18, a + 0.18, WR + 0.13, WR - 0.13, '#353b43', rx=2, extra=' stroke="#4d5560" stroke-width="1"')


for a in (3.35, CAR + GANG / 2):
    wheel(a)
rect(4.0, 2.7, RED_B - 0.05, 0.50, EQUIP, rx=2)
# Panels under the joint, in front of its axle.
rect(CAR - 0.05, B0 + 0.05, RED_B, SKIRT + 0.04, EQUIP)

# ---------------------------------------------------------------- the cab car's body
R1 = 0.35 * M
outline = (f'M{P(CAR, SKIRT)} V{Y(CROWN) + R1:.1f} Q{x(CAR):.1f},{Y(CROWN):.1f} {x(CAR) + R1:.1f},{Y(CROWN):.1f} '
           f'H{x(1.75):.1f} Q{P(1.55, CROWN)} {P(1.38, 3.71)} C{P(1.00, 3.52)} {P(0.62, 2.98)} {P(0.43, 2.25)} '
           f'L{P(0.27, 1.63)} Q{P(0.22, 1.43)} {P(0.12, 1.40)} Q{P(0.0, 1.36)} {P(0.0, 1.15)} L{P(0.0, 0.84)} '
           f'L{P(0.02, 0.45)} Q{P(0.05, SKIRT)} {P(0.30, SKIRT)} L{P(2.80, SKIRT)} L{P(2.80, 0.52)} L{P(3.90, 0.52)} '
           f'L{P(3.90, SKIRT)} Z')
d.clip('c1', outline)
d.group('c1')
livery(CAR + 0.1, -0.2, band=((CAR + 0.1, SEAM),))
# Dark bumper under the red lower front.
rect(0.9, -0.2, 0.84, SKIRT - 0.1, 'url(#skirt)')
# Windscreen and its black surround, from the profile back to the glass's near edge.
d.add(f'<path d="M{P(-0.3, 3.95)} L{P(1.60, 3.95)} L{P(1.38, 3.71)} C{P(1.20, 3.40)} {P(0.85, 2.55)} {P(0.61, 1.48)} '
      f'L{P(-0.3, 1.40)} Z" fill="#14171b"/>')
d.add(f'<path d="M{P(1.22, 3.62)} C{P(1.05, 3.30)} {P(0.78, 2.55)} {P(0.58, 1.62)}" fill="none" stroke="#3a4450" stroke-width="2"/>')
d.end()
d.add(f'<path d="{outline}" fill="none" stroke="#1b1f25" stroke-width="0.8" opacity="0.5"/>')
# The cab module's seam.
d.add(f'<path d="M{P(SEAM + 0.02, CROWN)} Q{P(SEAM - 0.06, 2.3)} {P(SEAM, RED_B)}" fill="none" stroke="{LINE}" stroke-width="1.4"/>', RED)
d.add(f'<path d="M{P(SEAM + 0.02, CROWN)} Q{P(SEAM - 0.06, 2.3)} {P(SEAM, RED_B)}" fill="none" stroke="#9aa1a8" stroke-width="1.4"/>', 'plain')

# Saloon windows.
for a, b in ((5.68, 3.89), (7.73, 6.02), (12.12, 10.56), (14.01, 12.40)):
    window(a, b)
# Cab door, its window and the gutter over it.
for L, c in ((RED, LINE), ('plain', '#8d949c')):
    rect(3.11, 2.13, 3.15, 1.01, 'none', L, rx=5, extra=f' stroke="{c}" stroke-width="1.4"')
window(2.97, 2.21, top=3.06, bottom=2.19)
rect(3.18, 2.10, 3.27, 3.22, '#2a2f36', rx=1)


def door(a, b):
    """Two sliding leaves, a tall narrow window in each (white leaves on the new livery, red on the old)."""
    rect(a, b, DOOR_T, DOOR_B, 'url(#dwhite)', NEW, rx=4)
    rect(a, b, DOOR_T, DOOR_B, 'none', rx=4, extra=' stroke="#3a4048" stroke-width="1.4"')
    c = (a + b) / 2
    d.add(f'<line x1="{x(c):.1f}" y1="{Y(DOOR_T - 0.02):.1f}" x2="{x(c):.1f}" y2="{Y(DOOR_B + 0.02):.1f}" stroke="#3a4048" stroke-width="1.8"/>')
    for w0, w1 in ((a - 0.33, a - 0.97), (b + 0.97, b + 0.33)):
        rect(w0, w1, 2.71, 1.68, 'url(#glass)', rx=8, extra=' stroke="#0b0d10" stroke-width="1.6"')


door(10.23, 7.93)

# ---------------------------------------------------------------- front: anticlimbers and coupler
rect(0.30, -0.06, 0.84, 0.62, '#5b636c', rx=2, extra=' stroke="#3f464f" stroke-width="1"')
for h in (0.68, 0.73, 0.78):
    d.add(f'<line x1="{x(0.28):.1f}" y1="{Y(h):.1f}" x2="{x(-0.04):.1f}" y2="{Y(h):.1f}" stroke="#3f464f" stroke-width="1"/>')
rect(0.25, -0.15, 1.10, 0.80, '#2a2f36', rx=2, extra=' stroke="#4d5560" stroke-width="1"')

if __name__ == '__main__':
    main(d)
