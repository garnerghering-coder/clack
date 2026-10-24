"""ASEA X11 (rebuilt X10, 2-car EMU) in Krösatåg's livery: the motor car (X11-A, with the pantograph) whole, cab to the
right, and the end of the trailer. docs/TRAIN_ART.md; style as x31.py.

Sources (all retrieved 2026-10-22):
- Garner's photos (2026-10-22): 73.webp, X11 3107 nearly side-on from below (the main measuring photo, rectified, see
  below); 72.webp, X11 3137 at Karlskrona, 3/4 (colours, cab front, the front corner, the red skirt and plough, the
  bogie under the cab, the joint between the cars); 74.png, X11 3111, 3/4 (same livery and layout).
- järnväg.net, https://www.jarnvag.net/vagnguide/x11: 3137 Karlskrona 2024-08-24 (extX11_3137_Karlskrona_240824.jpg, the
  same view as 72), 3107 Hässleholm 2017-07-23 (extX11_3107Hassleholm170723stor.jpg: front face, used at 203 px/m from
  the 1.75 m buffer spacing for the front heights), "Dörr på X11 3137" 2024-08-24 (extX11_3137_dorr_240824.jpg: a
  frontal view of a door; all the livery heights), Skånetrafiken X11 at Åkarp 2006-06-11 (extX11_Akarp060611stor.jpg:
  the whole unit side-on from far away, old purple livery, same body: nose silhouette, roof equipment, car ends).
  The page (and krosatagen.se/om-krosatagen) also give: 49 868 mm over buffers for the unit, axles Bo'Bo'+2'2'.
- sv.wikipedia "X10 (motorvagn)" and de.wikipedia "SJ X10" (action=raw): 49 868 mm, wheels 920 mm, bogie centres
  18 000 mm, bogie axles 2 600 mm, width 3 080 mm, height 3 790 mm "without pantograph".
Measuring:
- 73.webp (1000x844) rectified with a homography: the yellow edge, red stripe top and bottom (fitted along the car, rms
  0.4 px, straight) meet at the vanishing point (-1915, 706); door and window edges give the vertical one (-226,
  -22600). In the rectified frame the nine side windows come out 1.05-1.09 m wide (equal within 4%). Heights: the
  door photo (frontal) gives the true ratios; a 1-D projective fit maps 73's levels onto it (residuals <= 3 px = 1.3 cm).
- Scale: the car is 24.53 m from the nose tip to the rear end face ((49.868 - 0.39 m gangway - 2 x 0.21 m buffers) / 2,
  gangway and buffers from the Åkarp photo); the Åkarp photo and 73 agree on the rear end, both doors and the nose
  to 0.1 m once matched on the doors. That puts the door (two leaves) at 1.39 m wide and its height at 2.10 m (door
  photo: leaf height/width 3.015).
- Heights below the roof crown: the window frame top is 0.902 m below the crown (Åkarp: crown to window top / window
  height = 1.025, window frame 0.88 m). Check: the yellow under the windscreen comes out 1.715 m below the crown on the
  side (73) and 1.70 m on the front (3107 front, buffer scale). The rail is then 3.99 m below the crown (3107 front:
  buffer centres 2.95 m below the crown, standard buffer height 1.04 m), not the 3.79 m height Wikipedia gives; the
  two photos agree with each other, so the picture uses the photos (unverified: the X10 height figure's definition).
Measured (metres back from the nose tip; h = metres below the roof crown; body underside 3.09 m):
- livery (door photo / 73): yellow from the roof down to 0.712; silver ribbed strip 0.712-0.835; grey window band
  0.835-1.870; silver ribbed lower body 1.870-2.835; red stripe 2.835-3.09 (the body's bottom edge). Ribs 0.029 m apart.
  Grey band from 23.056 to the doors (0.05-0.07 m silver frame strips at 19.757/18.271 and 6.199/4.682), and in front
  of door F to a straight slanted end from (3.113, 0.835) to (2.612, 1.870); corners slightly rounded. The car's ends
  (23.06-24.53) are white above the ribs. Lower ribs run from the rear end to the cab door frame at 1.813; the upper
  strip over the grey band from 23.056 to 3.113. The cab section in front of the slant is smooth white.
- yellow at the cab: the band runs forward to a straight slanted edge from (0.557, 0.712) down to (0.178, 1.715), then
  along 1.715 to the nose (the yellow above the windscreen). Below it the lower front is white down to the red.
- red at the front: the stripe meets the front skirt at the corner and rises to 2.67 at the nose (3107 front: 2.67 at
  the centre, 2.84 at the corners); beam bottom 3.25, buffer centres 2.95, heads 0.33 m across, faces 0.22 m ahead of
  the nose tip (Åkarp). Plough 3.41-3.88. The beam's length along the side and the plough's outline are estimated from
  the 3/4 views (72, 3107), not measured side-on.
- nose (Åkarp silhouette, 22.7 px/m): roof crown to 1.05, corner through (0.87, 0.045) (0.74, 0.125) (0.67, 0.30);
  raked windscreen face straight from (0.60, 0.48) to (0.05, 1.76) (x = 0.80 - 0.42 h, 23 degrees); waist (tip) at 1.84;
  lower front back to (0.04, 1.97) (0.10, 2.15) (0.13, 2.30), then straight down at 0.14.
- windows (frame outer, 0.902-1.783): 23.007-21.872, 21.279-20.210 | door R | 17.793-16.706, 16.132-15.105,
  14.513-13.461, 12.748-11.703, 10.984-9.939, 9.353-8.308, 7.734-6.676 | door F | 4.20-3.15 (the large window).
- doors (two leaves, yellow): R 19.684-18.307, F 6.133-4.743; 0.876-2.971; leaf windows R 19.545-19.123 and
  18.863-18.440, F 5.969-5.571 and 5.299-4.882, 1.035-1.780; a step plate under each doorway 3.10-3.20 (door photo).
- cab door 1.571-0.973, 0.795-2.74 (72: its bottom 0.09 m above the red); window 1.510-1.027, 0.917-1.622; a handrail
  1.70 from 1.41 to 2.55. Red tail-lamp housing 0.936-0.653, 0.876-1.391; marker light above it 0.906-0.701,
  0.613-0.795.
- roof (Åkarp, h above the crown negative): yellow grille boxes on the roof shoulder 20.663-18.186, 13.328-10.875,
  6.102-4.652, 3.021-2.054 (73), -0.02-0.31; pantograph insulators 22.89-22.67 and 21.39-21.12 to -0.26 and its red base
  frame 22.76-21.12, -0.26 to -0.35 (raised in every photo, its arms above the picture: not drawn, as no_type76.py);
  boxes 20.15-17.94 (-0.40) and 17.94-16.17 (-0.35); breaker and disconnector 14.75-14.18 (-0.40) and 14.05-12.19
  (dark base to -0.30, red frame 13.85-12.35 to -0.62); domes 11.75-11.48, 11.31-10.95, 5.12-4.76; box 9.45-5.65 (-0.35); box over the
  cab 3.83-1.71 (-0.35).
- bogies: not seen side-on (grass in 73 and Åkarp); centres 3.265 and 21.265 (18.0 m apart, assumed central: 72 shows
  the front one under the cab door and large window), axles 2.6 m, wheels 0.92 m, centres 3.53 below the crown.
  Underfloor equipment between them to 3.48 (72).
- trailer end (Åkarp, 72: the cars are mirror images at the joint): gangway 0.39 m, light grey bellows; white end 1.47 m,
  then the grey band and a window.
Colours sampled from the door photo and 72: yellow #fed24f/#f5cf5c, doors #f2ab00, grey #8b9498, red #dc2f2f/#ff1433,
ribbed silver #d9ddd7.
Not drawn: lettering, numbers, names and logos; the pantograph's arms; the cab step and hoses (not measurable side-on).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

K = 'krosatag'
CAR, BODY, GANG, SHOW = 24.53, 3.09, 0.40, 1.6


class X11Drawing(Drawing):
    """The kit's drawing with a view box that takes the roof equipment, the buffers ahead of the nose and the rail."""

    def viewbox(self):
        right = self.x(-0.32)
        return f'{self.VB_X:.0f} 12 {right - self.VB_X:.0f} {self.ROOF + 4.05 * self.M - 12:.0f}'


d = X11Drawing(car_m=CAR, body_m=BODY, gangway_m=GANG, show_second_m=SHOW, liveries=[K])
x, M, ROOF, BASE, TIP, REAR = d.x, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
S = d.SECOND_END


def Y(h):
    """Height in metres below the roof crown -> drawing y."""
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
    """Catmull-Rom through (m, h) points -> SVG cubic segments (after an M to the first point)."""
    Q = [(x(m), Y(h)) for m, h in pts]
    out = []
    for i in range(len(Q) - 1):
        p0, p1, p2, p3 = Q[max(i - 1, 0)], Q[i], Q[i + 1], Q[min(i + 2, len(Q) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}')
    return f'M{Q[0][0]:.1f},{Q[0][1]:.1f} ' + ' '.join(out)


d.gradient('silver', ['#f2f3f2', '#e2e5e3', '#c9cdcc'])
d.gradient('yellow', ['#fdd64e', '#f6c935', '#eeb81c'])
d.gradient('door', ['#f8b511', '#eea300'])
d.gradient('red', ['#e8303a', '#cf1f2a'])
d.gradient('grille', ['#e6ae16', '#d89c0a'])
YEL, GREY, RED, DOORLINE = '#f2c12a', '#8b9498', '#dc2532', '#2b2f33'
EQUIP = '#2a2f36'

# Bands (h below the crown).
YEL_EDGE, GREY_TOP, GREY_BOT, RED_TOP = 0.712, 0.835, 1.870, 2.835
WIN_TOP, WIN_BOT = 0.902, 1.783
RIB = 0.029

# Nose outline (Åkarp silhouette), with the raked windscreen face as the straight line x = 0.80 - 0.42 h.
rake = [(0.80 - 0.42 * h, h) for h in (0.48, 0.75, 1.01, 1.28, 1.54)]
NOSE = [(1.05, 0.0), (0.87, 0.045), (0.74, 0.125), (0.67, 0.30), *rake, (0.05, 1.76), (0.0, 1.84), (0.035, 1.97), (0.10, 2.15), (0.13, 2.30), (0.14, 2.45)]
FRONT_X = 0.14  # the lower front, straight down to the body's bottom

# ---------------------------------------------------------------- trailer end (the sliver), behind everything
R2 = 0.2 * M  # rounded top corner of the car ends
d.clip('c2', f'M{d.VB_X - 10},{Y(BODY):.1f} V{ROOF} H{S - R2:.1f} Q{S},{ROOF} {S},{ROOF + R2:.1f} V{Y(BODY):.1f} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10:.1f}" height="{BODY * M:.1f}" fill="url(#body)"/>', 'plain')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10:.1f}" height="{BODY * M:.1f}" fill="url(#silver)"/>', K)
B0 = CAR + GANG  # trailer's end, metres from the cab car's nose
for i in range(int((RED_TOP - GREY_BOT) / RIB)):
    h = GREY_BOT + 0.02 + i * RIB
    d.add(f'<line x1="{d.VB_X - 10}" y1="{Y(h):.1f}" x2="{S}" y2="{Y(h):.1f}" stroke="#000" stroke-opacity="0.09" stroke-width="0.5"/>')
rect(B0 + 3, B0 - 0.1, 0, YEL_EDGE, 'url(#yellow)', K)
rect(B0 + 3, B0 - 0.1, 0, 0.12, 'url(#roof)', 'plain')
rect(B0 + 3, B0 + 1.474, GREY_TOP, GREY_BOT, GREY, K, rx=1.5)
rect(B0 + 3, B0 - 0.1, RED_TOP, BODY + 0.1, 'url(#red)', K)
d.add(f'<rect x="{x(B0 + 3):.1f}" y="{Y(WIN_TOP):.1f}" width="{x(B0 + 1.523) - x(B0 + 3):.1f}" height="{(WIN_BOT - WIN_TOP) * M:.1f}" rx="4" fill="#0b0d10"/>')
d.end()
rect(B0 + 3, B0 + 0.3, BODY, 3.35, EQUIP)

# Gangway bellows between the cars (light grey, 72).
rect(CAR, B0, 0.30, 3.05, '#c9c5ba')
for i in range(1, 5):
    m = CAR + i * GANG / 5
    d.add(f'<line x1="{x(m):.1f}" y1="{Y(0.34):.1f}" x2="{x(m):.1f}" y2="{Y(3.01):.1f}" stroke="#a39d90" stroke-width="1.2"/>')

# ---------------------------------------------------------------- running gear (behind the body)
WC, WR = 3.53, 0.46


def bogie(c, axle=2.6):
    """Wheels behind the bogie frame, only their lower part showing; axle boxes at the wheel centres."""
    s = axle / 2
    for a in (c - s, c + s):
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="{WR * M - 1:.1f}" fill="#1b1f25" stroke="#727b86" stroke-width="2"/>')
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="4" fill="#6d7681"/>')
    x0, x1 = sorted((x(c - s - WR - 0.1), x(c + s + WR + 0.1)))
    d.add(
        f'<path d="M{x0:.1f},{Y(BODY):.1f} H{x1:.1f} V{Y(3.56):.1f} Q{x1:.1f},{Y(3.62):.1f} {x1 - 8:.1f},{Y(3.62):.1f} '
        f'H{x(c + s) + 7:.1f} V{Y(3.58):.1f} H{x(c - s) - 7:.1f} V{Y(3.62):.1f} H{x0 + 8:.1f} Q{x0:.1f},{Y(3.62):.1f} {x0:.1f},{Y(3.56):.1f} Z" '
        f'fill="{EQUIP}" stroke="#3f464f" stroke-width="1.2"/>'
    )
    for a in (c - s, c + s):
        rect(a - 0.2, a + 0.2, 3.36, 3.66, '#353b43', rx=2, extra=' stroke="#4d5560" stroke-width="1"')
    d.add(f'<line x1="{x(c - 0.35):.1f}" y1="{Y(3.30):.1f}" x2="{x(c + 0.35):.1f}" y2="{Y(3.30):.1f}" stroke="#6d7681" stroke-width="2.4" stroke-linecap="round"/>')


rect(19.1, 5.4, BODY - 0.02, 3.48, EQUIP, rx=2, extra=' stroke="#3f464f" stroke-width="1.2"')
for c in (21.265, 3.265):
    bogie(c)
# Step plates under the doorways (door photo).
for a, b in ((19.614, 18.377), (6.063, 4.813)):
    rect(a, b, BODY - 0.01, 3.20, '#9aa1a8', rx=1, extra=f' stroke="{DOORLINE}" stroke-width="1"')

# ---------------------------------------------------------------- cab car body
nose = smooth(NOSE)
outline = (f'M{REAR},{Y(BODY):.1f} V{ROOF + R2:.1f} Q{REAR},{ROOF} {REAR + R2:.1f},{ROOF} H{x(1.05):.1f} '
           f'{nose[nose.index("C"):]} L{x(FRONT_X):.1f},{Y(BODY):.1f} Z')
d.clip('c1', outline)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{BODY * M + 8:.1f}" fill="url(#body)"/>', 'plain')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{BODY * M + 8:.1f}" fill="url(#silver)"/>', K)
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{0.12 * M + 4:.1f}" fill="url(#roof)"/>', 'plain')

# Ribs: lower body from the rear end to the cab door frame; the strip over the window band.
for i in range(int((RED_TOP - GREY_BOT) / RIB)):
    h = GREY_BOT + 0.02 + i * RIB
    d.add(f'<line x1="{REAR}" y1="{Y(h):.1f}" x2="{x(1.813):.1f}" y2="{Y(h):.1f}" stroke="#000" stroke-opacity="0.09" stroke-width="0.5"/>')
for i in range(int((GREY_TOP - YEL_EDGE) / RIB)):
    h = YEL_EDGE + 0.02 + i * RIB
    d.add(f'<line x1="{x(23.056):.1f}" y1="{Y(h):.1f}" x2="{x(3.113):.1f}" y2="{Y(h):.1f}" stroke="#000" stroke-opacity="0.09" stroke-width="0.5"/>')

# Paint: yellow roof and band, with the slanted edge at the cab and the yellow above the windscreen.
poly([(CAR + 0.1, -0.2), (CAR + 0.1, YEL_EDGE), (0.557, YEL_EDGE), (0.178, 1.715), (-0.3, 1.715), (-0.3, -0.2)], 'url(#yellow)', K)
# Grey window band: rear, middle, and in front of door F to its slanted end.
rect(23.056, 19.757, GREY_TOP, GREY_BOT, GREY, K, rx=2)
rect(18.271, 6.199, GREY_TOP, GREY_BOT, GREY, K)
poly([(4.682, GREY_TOP), (3.113, GREY_TOP), (2.612, GREY_BOT), (4.682, GREY_BOT)], GREY, K, extra=' stroke-linejoin="round"')
# Red stripe along the bottom, rising at the front corner to the skirt's top.
red = (f'M{P(CAR + 0.1, RED_TOP)} L{P(0.45, RED_TOP)} Q{P(0.22, RED_TOP)} {P(0.14, 2.67)} L{P(-0.3, 2.67)} '
       f'L{P(-0.3, BODY + 0.2)} L{P(CAR + 0.1, BODY + 0.2)} Z')
d.paint(f'<path d="{red}" fill="url(#red)"/>', K)
d.end()

# Windows.
for a, b in ((23.007, 21.872), (21.279, 20.210), (17.793, 16.706), (16.132, 15.105), (14.513, 13.461), (12.748, 11.703),
             (10.984, 9.939), (9.353, 8.308), (7.734, 6.676), (4.20, 3.15)):
    rect(a, b, WIN_TOP, WIN_BOT, '#0b0d10', rx=4)
    rect(a - 0.05, b + 0.05, WIN_TOP + 0.05, WIN_BOT - 0.05, 'url(#glass)', rx=3)


def door(a, b, wins):
    """Two leaves: yellow (Krösatåg) or body colour (plain), dark rubber edges, split, a window in each."""
    rect(a, b, 0.876, 2.971, 'url(#door)', K, rx=3)
    rect(a, b, 0.876, 2.971, 'url(#body)', 'plain', rx=3)
    rect(a, b, 0.876, 2.971, 'none', rx=3, extra=f' stroke="{DOORLINE}" stroke-width="1.4"')
    mid = (a + b) / 2
    d.add(f'<line x1="{x(mid):.1f}" y1="{Y(0.89):.1f}" x2="{x(mid):.1f}" y2="{Y(2.96):.1f}" stroke="{DOORLINE}" stroke-width="1.4"/>')
    for p, q in wins:
        rect(p, q, 1.035, 1.780, 'url(#glass)', rx=4.4, extra=f' stroke="{DOORLINE}" stroke-width="1.6"')


door(19.684, 18.307, ((19.545, 19.123), (18.863, 18.440)))
door(6.133, 4.743, ((5.969, 5.571), (5.299, 4.882)))

# Cab door, its window and handrail; the tail-lamp housing and marker light by the corner.
d.add(f'<path d="M{P(1.571, 2.74)} V{Y(0.875):.1f} Q{x(1.571):.1f},{Y(0.795):.1f} {x(1.50):.1f},{Y(0.795):.1f} H{x(1.044):.1f} '
      f'Q{x(0.973):.1f},{Y(0.795):.1f} {x(0.973):.1f},{Y(0.875):.1f} V{Y(2.74):.1f} Z" fill="none" stroke="#7d858d" stroke-width="1.4"/>')
rect(1.510, 1.027, 0.917, 1.622, 'url(#glass)', rx=6, extra=' stroke="#0b0d10" stroke-width="2"')
rect(1.715, 1.685, 1.41, 2.55, '#9aa1a8', rx=1)
rect(0.936, 0.653, 0.876, 1.391, '#3a3f45', rx=2.5)
rect(0.915, 0.674, 0.90, 1.367, '#d42a35', rx=2)
rect(0.906, 0.701, 0.613, 0.795, '#5b636c', rx=1.5)
rect(0.88, 0.727, 0.635, 0.775, '#cfd5da', rx=1)

# ---------------------------------------------------------------- roof
# Grille boxes on the roof shoulder (yellow on Krösatåg), louvres.
for a, b in ((20.663, 18.186), (13.328, 10.875), (6.102, 4.652), (3.021, 2.054)):
    rect(a, b, -0.02, 0.31, 'url(#grille)', K, rx=2, extra=' stroke="#c98f06" stroke-width="0.8"')
    rect(a, b, -0.02, 0.31, '#b9bfc6', 'plain', rx=2, extra=' stroke="#8d949c" stroke-width="0.8"')
    n = int((a - b) / 0.11)
    for i in range(1, n):
        m = b + i * (a - b) / n
        d.add(f'<line x1="{x(m):.1f}" y1="{Y(0.02):.1f}" x2="{x(m):.1f}" y2="{Y(0.27):.1f}" stroke="#000" stroke-opacity="0.18" stroke-width="0.8"/>')
# Equipment on the roof (Åkarp).
BOX, DARK = '#9aa1a8', '#3a4048'
rect(20.15, 17.94, -0.40, 0.0, BOX, rx=1.5, extra=f' stroke="{DARK}" stroke-width="1"')
rect(17.94, 16.17, -0.35, 0.0, '#b4bac0', rx=1.5, extra=f' stroke="{DARK}" stroke-width="1"')
rect(9.45, 5.65, -0.35, 0.0, BOX, rx=1.5, extra=f' stroke="{DARK}" stroke-width="1"')
rect(9.45, 8.95, -0.35, 0.0, DARK, rx=1.5)
rect(6.15, 5.65, -0.35, 0.0, DARK, rx=1.5)
rect(3.83, 1.71, -0.35, 0.0, '#30353c', rx=2)
rect(14.75, 14.18, -0.40, 0.0, DARK, rx=1.5)
rect(14.05, 12.19, -0.30, 0.0, DARK, rx=1.5)
rect(13.85, 12.35, -0.62, -0.30, '#b8323a', rx=1.5)
for a, b, top in ((11.75, 11.48, -0.26), (11.31, 10.95, -0.26), (5.12, 4.76, -0.22)):
    cx, rx_, ry = (x(a) + x(b)) / 2, (x(b) - x(a)) / 2, -top * M
    d.add(f'<path d="M{x(a):.1f},{ROOF + 1} A{rx_:.1f},{ry:.1f} 0 0 1 {x(b):.1f},{ROOF + 1} Z" fill="{DARK}"/>')
# Pantograph: insulators and the red base frame (the raised arms are above the picture's frame).
for a, b in ((22.89, 22.67), (21.39, 21.12)):
    rect(a, b, -0.27, 0.0, '#5b5550', rx=1)
    for k in range(3):
        rect(a + 0.03, b - 0.03, -0.06 - k * 0.07, -0.03 - k * 0.07, '#7a726b', rx=1)
rect(22.76, 21.12, -0.35, -0.26, '#c42a33', rx=1)

# ---------------------------------------------------------------- front: buffer beam, buffers, plough
beam = (f'M{P(0.14, 2.67)} L{P(0.05, 2.70)} L{P(0.05, 3.25)} L{P(0.40, 3.25)} Q{P(0.62, 3.25)} {P(0.80, BODY)} '
        f'L{P(0.14, BODY)} Z')
d.add(f'<path d="{beam}" fill="url(#red)"/>', K)
d.add(f'<path d="{beam}" fill="#4a5058"/>', 'plain')
rect(0.75, 0.15, 3.25, 3.42, EQUIP)
plough = [(0.06, 3.41), (0.80, 3.41), (0.62, 3.88), (0.14, 3.88)]
poly(plough, 'url(#red)', K, extra=' stroke="#a8141f" stroke-width="1"')
poly(plough, '#3b4148', 'plain', extra=' stroke="#4d5560" stroke-width="1"')
for col, only in (('url(#red)', K), ('#4a5058', 'plain')):
    rect(0.05, -0.16, 2.83, 3.07, col, only, rx=1.5)
    rect(-0.16, -0.22, 2.785, 3.115, col, only, rx=2, extra=' stroke="#000" stroke-opacity="0.25" stroke-width="1"')

if __name__ == '__main__':
    main(d)
