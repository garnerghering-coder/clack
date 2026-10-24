"""SJ Rc6 electric locomotive (ASEA, Bo'Bo') leading SJ coaches, current SJ livery (black). docs/TRAIN_ART.md; x3.py is
the worked example.

Drawn: the Rc6 whole, cab A leading to the right, and the end of the first coach behind it (an SJ B7, the commonest
coach in SJ's loco-hauled trains: its end, gangway, end door and a little of the side). Liveries: `sj`, plus `plain`.

Sources (all retrieved 2026-10-22):
- Side photo (the measuring source): Wikimedia Commons "2024-12-07 4664 SJ Rc6 1358 som reservlok i Stockholm.jpg"
  (960 px thumbnail; current black livery, cab A on the right). https://commons.wikimedia.org/wiki/File:2024-12-07_4664_SJ_Rc6_1358_som_reservlok_i_Stockholm.jpg
  It is nearly side-on but not quite: the camera stood ahead of the loco and looked back 23 degrees. Rectified with a
  pinhole model (yaw only; no pitch: the horizon row 314 is the image centre, 320, within 6 px): the body's top and
  bottom lines meet at u=-4102, so f*cot(yaw)=4582 px; tan(yaw)=0.423 from the front face showing 40 px beyond the
  side's front corner (u 710-750); f=1938 px (a 70 mm-equivalent lens), distance 38.2 m. Scale: buffer face to buffer
  face = 15.52 m (rear buffer face u=132). Checks: the four portholes come out round (0.47 x 0.47 m); the bogie spring
  groups land at 3.8 and 11.4 m, 7.6 m apart (spec: bogie centres 7.7 m); the folded pantographs top out 4.4 m above
  rail (Wikipedia gives 4.5 m for the Rm, the same body).
- 3/4 photo, same livery: jarnvag.net Rc6 page, Rc6 1389 at Hallsberg 2017-07-24 (Frederik Tellerup)
  https://www.jarnvag.net/images/bild/lokguide/Rc6_1389_Hallsberg170724stor.jpg (https://www.jarnvag.net/lokguide/rc6).
  Rectified with its own pinhole model (vanishing point u=-382, horizon 407, yaw 68 degrees from round portholes,
  anchored on the portholes measured in the side photo: they fit to 3 cm). Used for what the side photo hides behind
  the station's pillars and platform: the machine-room door, the rail level, the bogies, the ploughs, the intake grille
  sections; and for the coach end, whose side lies in the loco's side plane (3.08 m vs 3.149 m wide).
- Coach: jarnvag.net B7 page (https://www.jarnvag.net/vagnguide/b7; 26.4 m, Sweden's commonest coach), photos
  extB7_5360_Falun250710.jpg (B7 5360, 2025-07-10: the current black livery, white door frames, dark roof),
  extBF7_5403_Norrkoping180403stor.jpg (BF7, same body: door window, roof edge and gangway heights, scaled by the door).
- sv.wikipedia "Rc-lok" (action=raw): Rc6 15 520 mm over buffers, bogie centres 7 700 mm, axles 2 700 mm, wheels
  1 300 mm, body width 3 149 mm, lowered-pantograph height 4 500 mm (Rm). jarnvag.net Rc6 page: black has been SJ's
  standard since 2006 and every SJ Rc6 is black. SJ's own loco-train icon (sj.se, "loktag") confirms the colours.
Measured (metres back from the front buffer face; heights h above the body underside of the machine room, which is
1.02 m above rail; rail from the Hallsberg photo at three wheels: 0.98, 1.05, 1.03 m):
- body: end planes 0.73 and 14.79; the flat side runs 1.21-14.29 and the cab corners are rounded in plan (radius about
  0.5 m: the Goteborg 3/4 photo of 1348, https://www.jarnvag.net/images/bild/lokguide/Rc6_1348_Goteborg160423.jpg, shows
  the corner 0.2 m wide at 45 degrees), so a true side view reaches the end planes. The end planes put the buffers at
  0.73 m, a standard buffer; the side photo, taken from ahead, shows the rear corner only up to its tangent at 14.29
  and the front face foreshortened beyond 1.21, which is why the overlay's photo looks 0.5 m shorter at each end; cab roof 2.63; intake grille band 2.33-2.70 from 3.02 to 12.50
  (top edge 2.84-12.68, slanted ends), sections at 5.6 and 10.25 (Hallsberg); corrugated machine-room side 2.75-12.73,
  0.505-2.327, a ledge at 1.39; smooth sill below; cab undersides 0.08 lower than the sill (-0.08).
- portholes (centres 4.04, 6.49, 8.96, 11.41 at 1.86), 0.47 m across, glass 0.385.
- cab A door 2.01-2.62, 0.58-2.34 with its window 2.11-2.53, 1.64-2.19; yellow rails at 2.66 and 1.975 (0.565..2.29);
  cab side window 1.23-1.89, 1.565-2.215; cab B window (rear, this side has no door there) 13.15-14.11, 1.565-2.24.
- machine-room door 10.03-10.53, 0.54-2.24, yellow rails beside it (Hallsberg; hidden by a pillar in the side photo).
- steps under both doors: recessed at 0.365-0.515 and 0.09-0.24, a hanging step at -0.26..-0.06; round sockets on the
  cab sides at 1.95 and 13.5 (0.35), lifting holes in the sill at 3.2 and 12.3 (0.34).
- corner handrails at the ends, 0.53..1.48; buffers centred 0.05, heads 0.34 high.
- bogies at 3.91 and 11.61 (spec, centred on the body), axles 1.35 either side, wheels 1.3 m centred at -0.37;
  light-grey spring brackets 2.0 m long at -0.11..-0.23 with two coil groups below (side photo and Hallsberg);
  red ploughs ahead of the outer axles down to 0.1 m above rail.
- roof: pantographs (folded single arm, knee inboard, head outboard) 2.35-4.69 and mirrored, base 2.78, top 3.39;
  roof box 7.32-8.50 up to 3.18; a red roof line at 3.05 between the pantographs; rod antennas at 1.48 and 13.03.
- coach B7: buffer 15.52-16.12, end at 16.08, gangway 15.6-16.08 (0.16..2.59), roof edge 2.47 and crown about 3.02 (Hallsberg roof silhouette, taken 0.5-1 m in from the side),
  corrugated side 0.08-2.39, end door (white frame) 16.125-17.125, -0.49..2.08, its window 16.34-16.875, 1.05-1.92.
Not drawn: lettering, numbers, SJ wings and the Bra Miljoval mark; couplings and hoses (behind the buffers); the coach's
bogie (its first axle is outside the picture).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

SJ = 'sj'
CAR, SHOW = 15.52, 2.4
TOP = 1.76  # band top above the side photo's eye level; heights below are in that frame (h), body underside -0.94


class RcDrawing(Drawing):
    """The kit's drawing with a taller view box: the pantographs stand 0.7 m over the body, the rail 1 m under it."""

    def viewbox(self):
        top = self.Y(2.56)
        return f'{self.VB_X:.0f} {top:.0f} {self.TIP + 8 - self.VB_X:.0f} {self.Y(-2.06) - top:.0f}'

    def Y(self, h):
        return self.ROOF + (TOP - h) * self.M


d = RcDrawing(car_m=CAR, body_m=TOP + 0.94, show_second_m=SHOW, gangway_m=0.0, liveries=[SJ])
x, Y, M = d.x, d.Y, d.M
RAIL = -1.96
d.gradient('sjblack', ['#3a3f45', '#2a2e33', '#1e2125'], stops=(0, 0.55, 1))
d.gradient('coachpaint', ['#34383d', '#282b30', '#1f2226'], stops=(0, 0.55, 1))
d.gradient('plough', ['#e0353d', '#c4222b'])
d.gradient('grille', ['#2a2f35', '#1b1f24'])
d.defs['cornerF'] = '<linearGradient id="cornerF" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.22"/></linearGradient>'
d.defs['cornerR'] = '<linearGradient id="cornerR" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.22"/></linearGradient>'
YELLOW, STEEL, ALU = '#f2c318', '#9aa1a8', '#c9ced3'


def P(m, h):
    return f'{x(m):.1f},{Y(h):.1f}'


def rect(m0, m1, h0, h1, fill, only=None, rx=0, extra=''):
    """A rectangle between two distances from the tip and two heights (either order)."""
    a, b = sorted((x(m0), x(m1)))
    t, u = sorted((Y(h0), Y(h1)))
    d.add(f'<rect x="{a:.1f}" y="{t:.1f}" width="{b - a:.1f}" height="{u - t:.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


def poly(pts, fill, only=None, extra=''):
    d.add(f'<path d="M{" L".join(P(m, h) for m, h in pts)} Z" fill="{fill}"{extra}/>', only)


def line(m0, h0, m1, h1, stroke, w=1.2, only=None, extra=''):
    d.add(f'<line x1="{x(m0):.1f}" y1="{Y(h0):.1f}" x2="{x(m1):.1f}" y2="{Y(h1):.1f}" stroke="{stroke}" stroke-width="{w}"{extra}/>', only)


def both(svg_fn):
    """The same element in yellow for SJ and in steel for the unpainted version."""
    svg_fn(YELLOW, SJ)
    svg_fn(STEEL, 'plain')


# ---------------------------------------------------------------- the coach (B7), behind the loco
CE = 16.08  # coach end (side corner)
CL = 15.52 + SHOW + 0.3  # beyond the left edge of the picture
d.clip('coach', f'M{x(CL):.1f},{Y(-0.90):.1f} V{Y(2.08):.1f} H{x(CE + 0.5):.1f} Q{x(CE + 0.04):.1f},{Y(2.06):.1f} {x(CE):.1f},{Y(1.53):.1f} '
               f'V{Y(-0.90):.1f} Z')
d.group('coach')
rect(CL, CE - 0.1, -1.0, 2.2, 'url(#body)', 'plain')
rect(CL, CE - 0.1, -1.0, 2.2, 'url(#coachpaint)', SJ)
rect(CL, CE - 0.1, 1.53, 2.2, 'url(#roof)', 'plain')
rect(CL, CE - 0.1, 1.53, 2.2, '#2f3338', SJ)
line(CL, 1.53, CE, 1.53, '#000', 1.0, extra=' stroke-opacity="0.25"')
for i in range(31):  # corrugated side behind the door
    h = 1.45 - i * 0.075
    if h < -0.86:
        break
    line(CL, h, 17.15, h, '#000', 0.9, extra=' stroke-opacity="0.16"')
    line(CL, h - 0.03, 17.15, h - 0.03, '#fff', 0.7, extra=' stroke-opacity="0.07"')
d.end()
d.add(f'<rect x="{x(17.9):.1f}" y="{Y(-0.90):.1f}" width="{x(17.15) - x(17.9):.1f}" height="{Y(-1.22) - Y(-0.90):.1f}" fill="#2a2f36"/>')
# End door: white frame (SJ) / outline (plain), black leaf, window; it runs down past the body to the steps.
rect(17.125, 16.125, -1.425, 1.14, '#eef0f2', SJ, rx=2)
rect(17.125 - 0.09, 16.125 + 0.09, -1.425 + 0.06, 1.14 - 0.09, '#202327', SJ, rx=1.5)
rect(17.125, 16.125, -1.425, 1.14, '#d5d9de', 'plain', rx=2, extra=' stroke="#8d949c" stroke-width="1.6"')
d.add(f'<rect x="{x(16.875):.1f}" y="{Y(0.98):.1f}" width="{x(16.34) - x(16.875):.1f}" height="{Y(0.11) - Y(0.98):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')
# Gangway bellows and the coach's buffer.
rect(16.08, 15.6, -0.78, 1.65, '#1d2125', rx=2)
for i in range(1, 5):
    m = 15.6 + i * (16.08 - 15.6) / 5
    line(m, -0.74, m, 1.61, '#3a4048', 1.3)
rect(16.12, 15.62, -0.82, -0.98, '#2a2f36')
rect(15.62, 15.52, -0.73, -1.07, '#3a4048', rx=1.5)

# ---------------------------------------------------------------- loco running gear (behind the body)
WC = RAIL + 0.65  # wheel centres


def bogie(c):
    """Rc bogie as the photos show it: the wheels mostly hidden behind the motors, the deep side frame and the axle
    boxes, only their lower rims showing; the light-grey spring bracket with two coil groups at the centre."""
    for a in (c - 1.35, c + 1.35):
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="{0.65 * M - 1:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
    rect(c - 2.0, c + 2.0, -0.94, -1.30, '#22262c')
    poly([(c - 2.0, -1.15), (c + 2.0, -1.15), (c + 2.0, -1.50), (c + 1.75, -1.62), (c - 1.75, -1.62), (c - 2.0, -1.50)], '#2a2f36', extra=' stroke="#3f464f" stroke-width="1.2"')
    for a in (c - 1.35, c + 1.35):
        rect(a - 0.24, a + 0.24, -1.14, -1.60, '#353b43', rx=2, extra=' stroke="#4d5560" stroke-width="1"')
        d.add(f'<circle cx="{x(a):.1f}" cy="{Y(WC):.1f}" r="4.5" fill="#6d7681"/>')
    for s in (-1, 1):
        for k in range(4):
            line(c + s * 0.08, -1.21 - k * 0.07, c + s * 0.5, -1.21 - k * 0.07, '#c3c8cd', 2.2, extra=' stroke-linecap="round"')
    poly([(c - 1.0, -1.03), (c + 1.0, -1.03), (c + 1.0, -1.15), (c + 0.12, -1.15), (c, -1.22), (c - 0.12, -1.15), (c - 1.0, -1.15)], '#b9bfc5')


# Underslung equipment (the transformer) between the bogies, a dark mass in both photos.
rect(5.95, 9.57, -0.94, -1.34, '#2a2f36', rx=2, extra=' stroke="#3f464f" stroke-width="1.2"')
for c in (3.91, 11.61):
    bogie(c)


def plough(sign):
    """Red snowplough ahead of the outer axle, down to 0.1 m above rail (sign +1 front, -1 rear: mirrored)."""
    def m(v):
        return v if sign > 0 else CAR - v
    pts = [(m(2.0), -1.08), (m(0.98), -1.08), (m(0.80), -1.62), (m(0.86), RAIL + 0.1), (m(1.62), RAIL + 0.1), (m(2.0), -1.55)]
    poly(pts, 'url(#plough)', SJ)
    poly(pts, '#7d858d', 'plain')
    # Black and yellow hazard band along the bottom edge (SJ).
    poly([(m(0.83), -1.72), (m(1.66), -1.72), (m(1.62), RAIL + 0.1), (m(0.86), RAIL + 0.1)], YELLOW, SJ)
    for k in range(5):
        a = 0.90 + k * 0.16
        poly([(m(a), -1.72), (m(a + 0.07), -1.72), (m(a - 0.03), RAIL + 0.1), (m(a - 0.10), RAIL + 0.1)], '#14171a', SJ)


plough(1)
plough(-1)

# ---------------------------------------------------------------- loco body
F_END, R_END = 0.73, 14.79  # end planes
F_SIDE, R_SIDE = 1.21, 14.29  # where the flat side turns into the rounded corners
F_JOINT, R_JOINT = 2.75, 12.73  # cab / machine-room joints
CAB_TOP, R = 1.69, 0.30
body = (f'M{x(F_END):.1f},{Y(-1.02):.1f} V{Y(CAB_TOP - R):.1f} Q{x(F_END):.1f},{Y(CAB_TOP):.1f} {x(F_END + R):.1f},{Y(CAB_TOP):.1f} '
        f'H{x(2.84):.1f} V{Y(TOP):.1f} H{x(12.68):.1f} V{Y(CAB_TOP):.1f} H{x(R_END - R):.1f} Q{x(R_END):.1f},{Y(CAB_TOP):.1f} {x(R_END):.1f},{Y(CAB_TOP - R):.1f} '
        f'V{Y(-1.02):.1f} H{x(R_JOINT):.1f} V{Y(-0.94):.1f} H{x(F_JOINT):.1f} V{Y(-1.02):.1f} Z')
d.clip('loco', body)
d.group('loco')
rect(F_END - 0.1, R_END + 0.1, -1.1, 1.9, 'url(#body)', 'plain')
rect(F_END - 0.1, R_END + 0.1, -1.1, 1.9, 'url(#sjblack)', SJ)
# Rounded corners at both ends.
rect(F_END, F_SIDE, -1.1, 1.9, 'url(#cornerF)')
rect(R_SIDE, R_END, -1.1, 1.9, 'url(#cornerR)')
# Intake grille band along the roof edge, slanted ends, three sections.
poly([(2.84, TOP + 0.05), (12.68, TOP + 0.05), (12.50, 1.387), (3.02, 1.387)], 'url(#grille)')
for k in range(int((12.5 - 3.1) / 0.11)):
    m = 3.1 + k * 0.11
    line(m, TOP - 0.02, m, 1.40, '#3d444c', 0.9)
for m in (5.6, 10.25):
    line(m, TOP, m, 1.387, '#59616b', 2.2)
line(2.84, TOP, 3.02, 1.387, '#59616b', 2.2)
line(12.68, TOP, 12.50, 1.387, '#59616b', 2.2)
# Corrugated machine-room side, its ledge, the seams at the cab joints and the sill.
for i in range(26):
    h = 1.35 - i * 0.07
    if h < -0.42:
        break
    if abs(h - 0.45) < 0.04:
        continue
    line(F_JOINT, h, R_JOINT, h, '#000', 0.9, extra=' stroke-opacity="0.16"')
    line(F_JOINT, h - 0.025, R_JOINT, h - 0.025, '#fff', 0.7, extra=' stroke-opacity="0.08"')
line(F_JOINT, 0.45, R_JOINT, 0.45, '#fff', 1.4, extra=' stroke-opacity="0.18"')
line(F_JOINT, -0.435, R_JOINT, -0.435, '#000', 1.2, extra=' stroke-opacity="0.22"')
for m in (F_JOINT, R_JOINT):
    line(m, CAB_TOP, m, -1.0, '#000', 1.2, extra=' stroke-opacity="0.22"')
line(F_END, CAB_TOP - 0.17, R_END, CAB_TOP - 0.17, '#000', 1.0, extra=' stroke-opacity="0.18"')
d.end()

# Portholes.
for c in (4.04, 6.49, 8.96, 11.41):
    d.add(f'<circle cx="{x(c):.1f}" cy="{Y(0.92):.1f}" r="{0.235 * M:.1f}" fill="#0b0d10"/>')
    d.add(f'<circle cx="{x(c):.1f}" cy="{Y(0.92):.1f}" r="{0.1925 * M:.1f}" fill="url(#glass)"/>')


def window(m0, m1, h0, h1):
    """Cab window: aluminium frame, dark glass."""
    rect(m0, m1, h0, h1, ALU, rx=4)
    rect(m0 + 0.05, m1 - 0.05, h0 - 0.05, h1 + 0.05, 'url(#glass)', rx=3)


window(1.23, 1.89, 1.275, 0.625)
window(13.15, 14.11, 1.30, 0.625)


def door(m0, m1, top, bottom, win=None):
    rect(m0, m1, top, bottom, 'none', rx=3, extra=' stroke="#8d949c" stroke-width="1.6"')
    if win:
        w0, w1, wt, wb = win
        d.add(f'<rect x="{x(w1):.1f}" y="{Y(wt):.1f}" width="{x(w0) - x(w1):.1f}" height="{Y(wb) - Y(wt):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')


def steps(m0, m1):
    """Two recessed steps in the body and one hanging below it (yellow edges on SJ)."""
    for t, b in ((-0.425, -0.575), (-0.70, -0.85)):
        rect(m0, m1, t, b, '#14171a', rx=1)
        both(lambda c, o: rect(m0, m1, t, t - 0.035, c, o))
    rect(m0, m1, -1.0, -1.2, 'none', extra=' stroke="#14171a" stroke-width="1.8"')
    both(lambda c, o: rect(m0, m1, -1.17, -1.2, c, o))


door(2.01, 2.62, 1.40, -0.36, win=(2.11, 2.525, 1.25, 0.70))
both(lambda c, o: rect(2.64, 2.68, 1.35, -0.375, c, o, rx=1))
both(lambda c, o: rect(1.955, 1.995, 1.35, -0.375, c, o, rx=1))
steps(2.175, 2.575)
door(10.03, 10.53, 1.30, -0.40)
both(lambda c, o: rect(10.56, 10.60, 1.25, -0.40, c, o, rx=1))
both(lambda c, o: rect(9.96, 10.00, 1.25, -0.40, c, o, rx=1))
steps(10.08, 10.48)
# Round sockets on the cab sides and lifting holes in the sill.
for m, h in ((1.95, -0.59), (13.5, -0.60)):
    d.add(f'<circle cx="{x(m):.1f}" cy="{Y(h):.1f}" r="{0.12 * M:.1f}" fill="#0f1215" stroke="#59616b" stroke-width="1"/>')
for m in (3.2, 12.3):
    d.add(f'<circle cx="{x(m):.1f}" cy="{Y(-0.60):.1f}" r="2.2" fill="#0f1215"/>')
# Corner handrails on the cab ends.
both(lambda c, o: rect(F_END - 0.06, F_END - 0.02, 0.54, -0.41, c, o, rx=1))
both(lambda c, o: rect(R_END + 0.02, R_END + 0.06, 0.55, -0.45, c, o, rx=1))

# Buffers.
for face, end in ((0.0, F_END), (CAR, R_END)):
    s = 1 if face < end else -1
    rect(end, face + s * 0.12, -0.78, -1.00, '#2a2f36')
    rect(face, face + s * 0.12, -0.72, -1.06, '#3a4048', rx=1.5)

# ---------------------------------------------------------------- roof equipment


def pantograph(sign):
    def m(v):
        return v if sign > 0 else CAR - v
    for v in (2.70, 3.50, 4.25):  # insulators
        rect(m(v) - 0.05, m(v) + 0.05, TOP - 0.02, 1.86, '#5b5550', rx=1)
    for col, only in (('#c8202a', SJ), ('#7d858d', 'plain')):
        rect(m(2.55), m(4.35), 1.86, 1.92, col, only, rx=1)
        d.add(f'<path d="M{P(m(2.70), 1.93)} L{P(m(4.60), 2.12)}" stroke="{col}" stroke-width="3.4" stroke-linecap="round" fill="none"/>', only)
        d.add(f'<path d="M{P(m(4.60), 2.16)} L{P(m(2.65), 2.36)}" stroke="{col}" stroke-width="2.4" stroke-linecap="round" fill="none"/>', only)
        d.add(f'<circle cx="{x(m(4.62)):.1f}" cy="{Y(2.14):.1f}" r="2.6" fill="{col}"/>', only)
    rect(m(2.40), m(2.80), 2.39, 2.45, '#8f969e', rx=1)
    for v in (2.40, 2.80):  # horns of the bow
        d.add(f'<path d="M{P(m(v), 2.42)} Q{P(m(v + (0.12 if v > 2.6 else -0.12)), 2.42)} {P(m(v + (0.14 if v > 2.6 else -0.14)), 2.34)}" stroke="#8f969e" stroke-width="1.6" fill="none"/>')


pantograph(1)
pantograph(-1)
line(4.45, 2.10, 11.07, 2.10, '#c8202a', 1.6, SJ)
line(4.45, 2.10, 11.07, 2.10, '#7d858d', 1.6, 'plain')
rect(7.32, 8.50, TOP - 0.02, 2.235, '#353b43', rx=2)
line(1.48, CAB_TOP, 1.48, 2.04, '#4b5158', 1.4)
line(13.03, CAB_TOP, 13.03, 2.01, '#4b5158', 1.4)

if __name__ == '__main__':
    main(d)
