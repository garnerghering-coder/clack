"""Alstom Coradia LINT 41, first generation (2-car diesel unit, Jakobs bogie in the middle), cab car, side view.
docs/TRAIN_ART.md; layout as regina.py (the cab car whole, cab to the right, the coupled end of the second car).
Liveries: `lokaltog` (yellow cab end sweeping into a white body, light grey lower band, dark grey skirt) and `vores-tog`
(Arriva's teal with a cream sweep over the cab, run unchanged by DSB Vores Tog) and `gocollective` (GoCollective's white
repaint, also now run by Vores Tog), plus `plain`.

Sources:
- Garner's photos (2026-10-28): 164.webp (Arriva AR 1012, nearly side-on, overcast: the shape, every window, the
  door and the Arriva paint were traced from it), 165.webp and 167.webp (Arriva, 3/4 front in sun: the nose, the
  colours), 166.png (a unit in Arriva paint with Vores Tog stickers, 2026: video thumbnail with overlay text, used only
  to confirm that DSB Vores Tog, which took over the former Arriva lines on 1 Sep 2026, kept Arriva's paint).
- Garner's photo 191.webp (2026-10-28): GoCollective AR 2043 in the white paint, 3/4 front, sharp, in sun.
- Lokaltog's own photo, drone shot of a LINT 41 near the coast, 2025-03-20
  (https://www.lokaltog.dk/media/r41ek21e/slide-71_dji_20250320102659_0046_d.jpg, retrieved 2026-10-28, full size
  8064 x 6048, saved as scratchpad/dk_lint41/ref/drone_full.jpg): the train nearly side-on from above, both cab ends.
  The Lokaltog livery edges were traced from it. Also Lokaltog's press photo 04_helsingoer_02_405_rgb.jpg (cab side
  close up) for the colours. The owner's chat photos (a Lokaltog unit, a Märklin model, Lokalbanen LB 215) agree but
  were not on disk, so nothing was measured from them.
- Alstom data sheet for the 2-car LINT (2005, Abellio order): 41 810 mm long (over couplers), 2 750 mm wide.

How the photos were measured:
- 164.webp: a 1-D projective map along the side, fitted on 17 pairs of mirrored edges (car 1's windows and door
  against car 2's), with the articulation at the middle of a 40.4 m nose-to-nose body (41.81 m over couplers less two
  couplers of about 0.7 m each, estimated): residuals 0.01-0.05 m. Heights from a pinhole model (26 mm-equivalent lens,
  1443 px, horizon at the window bottoms, camera 1.6 m above rail from the rail line under the cab bogie); a drift of
  0.09 m per 10 m along the side (window tops read 2.88 at the front, 3.02 at the back) was taken out. Heights are
  therefore +-0.1 m in absolute terms; the drawing is to the photo's own proportions.
- Drone photo: an affine map from the side plane to the photo fitted on the corners of the three windows between the
  cab and the door (positions from 164.webp; residuals 1-4 px = about 0.03 m), then the yellow pixels scanned along
  the side in 0.25 m steps.
Measured (metres back from the nose tip; heights above rail):
- body: roof line 3.60 (the side's top as seen; the true roof top may be a little higher), underside 0.50 between the
  bogies, 0.40 under the cab section to 2.97 m, raised to 0.80 over the cab bogie (2.97-5.2, sloping down to 0.50 by
  5.9 m) and to 0.88 at the articulated end (from 17.3-17.9 m); car end 19.9, bellows to 20.5, articulation 20.2.
- nose: roof curving down from 2.9 m through (2.29, 3.47) (1.72, 3.25) (1.31, 2.93) (0.82, 2.43) (0.28, 1.73)
  (0.04, 1.30) to the front at 0.0 m (0.98), back under through (0.16, 0.54) (0.88, 0.40). The windscreen's side edge
  through (2.29, 3.40) (1.8, 2.96) (1.55, 2.69) (1.05, 2.08) (0.6, 1.7), its bottom at 1.60: the mean of 164.webp
  (from below) and the drone (from above), +-0.15.
- cab side window: rear edge 2.93, bottom 1.60 from 1.23 m, top edge curving from (2.93, 2.86) through (2.48, 2.70)
  (2.15, 2.49) (1.82, 2.18) to (1.23, 1.60); a frame bar at 2.37 m.
- windows (dark glass and frame): 3.70-5.34, 5.70-7.31, 7.66-8.83 | door | 11.53-13.14, 13.46-15.08, 15.39-17.01
  (the low-floor part, bottoms 1.23), 17.77-19.40; tops 2.88, bottoms 1.61.
- door: frame 9.66-11.15, 0.55-2.84, two leaves split at 10.40, panes 9.87-10.25 and 10.56-10.94 from 0.70 to 2.64.
- grille under the second window: 5.69-7.27, 1.06-1.36. Roof hoods 4.1-7.6 and 11.3-14.2, about 0.35 m high.
- cab bogie centre 4.05 m (middle of the body's cut-out); Jakobs bogie at the articulation.
Liveries:
- lokaltog (drone photo): yellow (#f6c000) from the nose back, its rear edge a sweep from the roof line at 9.45 m down
  through (8.55, 3.32) (7.6, 2.94), hidden by the second window, then (5.55, 1.82) (5.05, 1.36) (4.78, 0.96) to the
  skirt top at 4.67 m (the part behind the window drawn as a smooth curve between the slopes either side); its corner
  at the skirt rounded (owner, earlier drawings); white above, a light grey band 0.78-1.12 (the drone's colours
  differ only a little there), dark grey skirt below 0.78 rising to 0.94 at the nose; doors dark navy; roof and the cab
  roof's front edge dark grey (#575e66) over the windscreen only (LB 215 in the owner's chat photo; the drone shows
  yellow up to the roof line from 2.7 m back, so the grey stops there).
- vores-tog (164.webp, 167.webp): teal; cream from the front below the windscreen (down to 1.25) up and back over the
  cab side window to the roof at 3.72 m, its lower edge through (0.62, 1.25) (0.91, 1.40) (1.21, 1.66) (1.51, 1.95)
  (1.82, 2.24) (2.31, 2.70) (2.65, 2.89) (2.99, 3.04) (3.53, 3.34), corners rounded; grey cab roof edge over the
  windscreen; a yellow line at 1.00-1.05 from 3.1 m back, broken at the door; pale teal door leaves. This is Arriva's
  paint: DSB Vores Tog took over Arriva's Midtjylland lines on 1 Sep 2026 and kept it (166.png shows the stickers).
- gocollective (191.webp, positions from the shared shape; edges read against the windows, +-0.05 m): white; a dark
  grey band (#6f717b) from 2.94 down to 1.55 round every window and across the piers, stepping down to 1.17 under the
  three low-floor windows, and a 0.06 m dark grey surround on the cab side window; grey skirt below 0.85; the front face
  under the windscreen dark grey; grey cab roof front; door leaves and a door-wide stripe from the door to the roof
  yellow (#f7e01e). The GoCollective lettering is left out.
Which paint is the majority (searched 2026-10-28): no source gives a count. The 43 LINT 41s (railjournal.com,
"Denmark terminates GoCollective operating contract"; DSB took over on 1 Sep 2026) wore Arriva's teal from delivery
(2004-2012) until Arriva Denmark became GoCollective in 2023; GoCollective's news item "Tilbage på skinnerne i nye
klæder" (gocollective.dk, undated in the search result) describes one set returning after a crash repair with a new
exterior, and 191.webp shows AR 2043 white. No fleet repaint programme was found, so the teal is taken as the majority
and kept as `vores-tog`; the white paint is `gocollective`. Unverified.
Estimated or unverified: the bogies' wheelbase (1.9 m cab bogie, 2.4 m Jakobs) and wheel size (0.77 m), which no
source here gives; the plough under the nose (its outline is from 164.webp, low and in shadow); the exhaust stack.
Not drawn: logos, lettering, numbers and pictograms (Arriva's and Lokaltog's), the couplers, the small hatches.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

LT, VT, GC = 'lokaltog', 'vores-tog', 'gocollective'
ROOF_H, BASE_H = 3.60, 0.50
d = Drawing(car_m=19.9, body_m=ROOF_H - BASE_H, gangway_m=0.6, liveries=[LT, VT, GC])
x, y, M, ROOF, BASE, TIP, REAR = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR
d.gradient('white', ['#fdfdfd', '#f1f3f4', '#dfe3e6'])
d.gradient('teal', ['#2bb3c8', '#1fa1b6', '#178c9e'])

LT_YELLOW, LT_BAND, LT_SKIRT, LT_DOOR, LT_CAP = '#f6c000', '#d3d8dc', '#5c6269', '#1f2b3d', '#575e66'
VT_CREAM, VT_CAP, VT_LINE, VT_DOOR = '#f1f1e3', '#5d6770', '#e8c31c', '#7cc4be'
PLAIN_CAP = '#a4abb2'
GC_BAND, GC_YELLOW, GC_SKIRT, GC_FRONT, GC_CAP = '#6f717b', '#f7e01e', '#7d8186', '#454b53', '#6c7279'


def Y(h):
    """Height above rail (m) -> drawing y."""
    return y((ROOF_H - h) / (ROOF_H - BASE_H))


def P(*pts):
    """(metres from the nose, height above rail) pairs -> 'x,y' drawing coordinates."""
    return ' '.join(f'{x(m):.1f},{Y(h):.1f}' for m, h in pts)


def smooth(pts):
    """A Catmull-Rom curve through the points, as cubic Bézier segments (the first point is the current one)."""
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2 = pts[max(i - 1, 0)], pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{P(c1, c2, p2)}')
    return ' '.join(out)


def rect(m0, m1, h_top, h_bot, fill, only=None, rx=0):
    d.add(f'<rect x="{x(m1):.1f}" y="{Y(h_top):.1f}" width="{x(m0) - x(m1):.1f}" height="{Y(h_bot) - Y(h_top):.1f}" rx="{rx}" fill="{fill}"/>', only)


def window(m0, m1, top=2.88, bottom=1.61):
    d.windows(x(m1), x(m0), 1, (ROOF_H - top) / (ROOF_H - BASE_H), (ROOF_H - bottom) / (ROOF_H - BASE_H))


# ---- Second car: its articulated end (the mirror of this car's rear). ----
S = d.SECOND_END
d.clip('c2', f'M{d.VB_X - 10},{Y(0.88):.1f} V{ROOF} H{S - 6} Q{S},{ROOF} {S},{ROOF + 6} V{Y(0.88):.1f} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#white)"/>', LT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{Y(1.12):.1f}" width="{S - d.VB_X + 10}" height="{Y(0.78) - Y(1.12):.1f}" fill="{LT_BAND}"/>', LT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#teal)"/>', VT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{Y(1.05):.1f}" width="{x(20.65) - d.VB_X + 10:.1f}" height="{Y(1.00) - Y(1.05):.1f}" fill="{VT_LINE}"/>', VT)
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF}" width="{S - d.VB_X + 10}" height="{d.H}" fill="url(#white)"/>', GC)
d.paint(f'<rect x="{d.VB_X - 10}" y="{Y(0.85):.1f}" width="{S - d.VB_X + 10}" height="{Y(0.3) - Y(0.85):.1f}" fill="{GC_SKIRT}"/>', GC)
d.paint(f'<rect x="{d.VB_X - 10}" y="{Y(2.94):.1f}" width="{S - d.VB_X + 10}" height="{Y(1.55) - Y(2.94):.1f}" fill="{GC_BAND}"/>', GC)
window(21.0, 22.63)
d.end()
# Bellows between the cars, down to the raised car ends (the kit's gangway runs to the full body depth).
d.add(f'<rect x="{S}" y="{ROOF + 6}" width="{REAR - S}" height="{Y(0.95) - ROOF - 6:.1f}" fill="#3a4047"/>')
for i in range(1, int((REAR - S) / 4)):
    d.add(f'<line x1="{S + i * 4}" y1="{ROOF + 8}" x2="{S + i * 4}" y2="{Y(0.97):.1f}" stroke="#4c535b" stroke-width="1.4"/>')

# ---- Cab car. ----
nose = [(2.29, 3.47), (1.93, 3.35), (1.72, 3.25), (1.51, 3.09), (1.31, 2.93), (0.82, 2.43), (0.5, 2.05), (0.28, 1.73),
        (0.09, 1.46), (0.04, 1.30), (0.0, 0.98), (0.02, 0.69), (0.16, 0.54), (0.5, 0.45), (0.88, 0.40)]
d.clip(
    'c1',
    f'M{REAR},{Y(0.88):.1f} V{ROOF + 6} Q{REAR},{ROOF} {REAR + 6},{ROOF} L{P((2.9, ROOF_H))} '
    f'Q{P((2.45, ROOF_H), (2.29, 3.47))} {smooth(nose)} '
    f'L{P((2.97, 0.40), (2.97, 0.80), (5.2, 0.80), (5.9, 0.50), (17.3, 0.50), (17.9, 0.88))} Z',
)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.3) - ROOF + 4:.1f}" fill="url(#body)"/>')

# Lokaltog: white body, light grey band, the yellow cab end, dark grey skirt.
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.3) - ROOF + 4:.1f}" fill="url(#white)"/>', LT)
d.paint(f'<rect x="{REAR}" y="{Y(1.12):.1f}" width="{TIP - REAR + 10}" height="{Y(0.78) - Y(1.12):.1f}" fill="{LT_BAND}"/>', LT)
sweep = [(9.45, ROOF_H), (9.3, 3.50), (9.05, 3.44), (8.55, 3.32), (8.05, 3.14), (7.6, 2.94), (6.575, 2.49), (5.55, 1.82),
         (5.05, 1.36), (4.78, 0.96)]
d.paint(
    f'<path d="M{P((-0.5, 3.9), (9.45, 3.9), (9.45, ROOF_H))} {smooth(sweep)} Q{P((4.67, 0.78), (4.45, 0.78))} '
    f'L{P((-0.5, 0.78))} Z" fill="{LT_YELLOW}"/>',
    LT,
)
d.paint(f'<path d="M{P((19.95, 0.78), (1.1, 0.78))} Q{P((0.45, 0.80), (0.15, 0.94))} L{P((-0.5, 0.96), (-0.5, 0.2), (19.95, 0.2))} Z" fill="{LT_SKIRT}"/>', LT)

# Vores Tog (Arriva paint): teal, the cream sweep over the cab, the yellow line.
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.3) - ROOF + 4:.1f}" fill="url(#teal)"/>', VT)
cream_edge = [(3.53, 3.34), (3.17, 3.10), (2.99, 3.04), (2.65, 2.89), (2.31, 2.70), (1.98, 2.39), (1.82, 2.24), (1.51, 1.95),
              (1.21, 1.66), (0.91, 1.40), (0.62, 1.26)]
d.paint(
    f'<path d="M{P((-0.5, 3.9), (3.95, 3.9), (3.95, ROOF_H))} Q{P((3.72, ROOF_H), (3.66, 3.50))} L{P((3.53, 3.34))} '
    f'{smooth(cream_edge)} Q{P((0.40, 1.25), (0.2, 1.25))} L{P((-0.5, 1.25))} Z" fill="{VT_CREAM}"/>',
    VT,
)
for a, b in ((3.1, 9.62), (11.19, 19.95)):
    d.paint(f'<rect x="{x(b):.1f}" y="{Y(1.05):.1f}" width="{x(a) - x(b):.1f}" height="{Y(1.00) - Y(1.05):.1f}" fill="{VT_LINE}"/>', VT)

# GoCollective (owner's photo 191.webp): white, a dark grey band round the windows (stepping down with the low-floor
# windows), a grey skirt, the front face below the windscreen dark grey, the door and a stripe above it to the roof yellow.
d.paint(f'<rect x="{REAR}" y="{ROOF - 4}" width="{TIP - REAR + 10}" height="{Y(0.3) - ROOF + 4:.1f}" fill="url(#white)"/>', GC)
d.paint(f'<path d="M{P((19.95, 0.85), (1.2, 0.85))} Q{P((0.5, 0.85), (0.3, 0.95))} L{P((-0.5, 0.95), (-0.5, 0.2), (19.95, 0.2))} Z" fill="{GC_SKIRT}"/>', GC)
for a, b, bot in ((2.93, 9.66, 1.55), (11.15, 17.07, 1.17), (17.07, 19.95, 1.55)):
    d.paint(f'<rect x="{x(b):.1f}" y="{Y(2.94):.1f}" width="{x(a) - x(b):.1f}" height="{Y(bot) - Y(2.94):.1f}" fill="{GC_BAND}"/>', GC)
d.paint(f'<path d="M{P((0.45, 1.62))} C{P((0.33, 1.45), (0.26, 1.20), (0.26, 1.0))} C{P((0.26, 0.85), (0.32, 0.75), (0.45, 0.66))} '
        f'L{P((-0.5, 0.66), (-0.5, 1.62))} Z" fill="{GC_FRONT}"/>', GC)
d.paint(f'<rect x="{x(11.15):.1f}" y="{ROOF - 4}" width="{x(9.66) - x(11.15):.1f}" height="{Y(2.84) - ROOF + 4:.1f}" fill="{GC_YELLOW}"/>', GC)

# Windscreen.
screen = [(2.29, 3.40), (1.8, 2.96), (1.55, 2.69), (1.05, 2.08), (0.6, 1.70), (0.45, 1.60)]
d.add(f'<path d="M{P((2.6, 3.9), (2.6, 3.42))} L{P((2.29, 3.40))} {smooth(screen)} L{P((-0.5, 1.60), (-0.5, 3.9))} Z" fill="url(#glass)"/>')
d.add(f'<path d="M{P((2.29, 3.40))} {smooth(screen)} L{P((-0.5, 1.60))}" fill="none" stroke="#0b0d10" stroke-width="2"/>')
# The cab roof's front edge over the windscreen: grey (dark grey on Arriva's paint).
# Arriva's runs back to the cream's end at the roof (3.75 m); on the others it stops over the cab (drone photo: yellow
# up to the roof line from 2.7 m back).
def cap(back):
    return f'M{P((back, 3.9), (back, ROOF_H))} Q{P((2.45, 3.48), (2.2, 3.33))} L{P((1.31, 2.90), (-0.5, 2.90), (-0.5, 3.9))} Z'


d.add(f'<path d="{cap(2.7)}" fill="{PLAIN_CAP}"/>', 'plain')
d.paint(f'<path d="{cap(2.7)}" fill="{LT_CAP}"/>', LT)
d.paint(f'<path d="{cap(2.7)}" fill="{GC_CAP}"/>', GC)
d.paint(f'<path d="M{P((3.75, 3.9), (3.75, ROOF_H), (2.9, 3.48))} Q{P((2.45, 3.44), (2.2, 3.33))} L{P((1.31, 2.90), (-0.5, 2.90), (-0.5, 3.9))} Z" fill="{VT_CAP}"/>', VT)
d.add(f'<ellipse cx="{x(0.07):.1f}" cy="{Y(1.38):.1f}" rx="2.2" ry="3.5" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')

# Cab side window (frame bar at 2.37 m).
cabwin = [(2.80, 2.85), (2.48, 2.70), (2.15, 2.49), (1.82, 2.18), (1.50, 1.88), (1.23, 1.60)]
d.paint(f'<path d="M{P((2.95, 1.55), (2.95, 2.80))} Q{P((2.95, 2.94), (2.80, 2.93))} {smooth([(2.80, 2.93), (2.47, 2.78), (2.12, 2.56), (1.78, 2.24), (1.45, 1.92), (1.15, 1.55)])} Z" '
        f'fill="{GC_BAND}" stroke="{GC_BAND}" stroke-width="2" stroke-linejoin="round"/>', GC)
d.add(
    f'<path d="M{P((2.93, 1.60), (2.93, 2.80))} Q{P((2.93, 2.86), (2.80, 2.85))} {smooth(cabwin)} Z" fill="url(#glass)" '
    f'stroke="#0b0d10" stroke-width="2.5" stroke-linejoin="round"/>'
)
d.add(f'<line x1="{x(2.37):.1f}" y1="{Y(2.68):.1f}" x2="{x(2.37):.1f}" y2="{Y(1.61):.1f}" stroke="#0b0d10" stroke-width="2"/>')

# Joints: the cab module (3.72 m above the windows, 2.95 m below) and the car end.
d.add(f'<line x1="{x(3.72):.1f}" y1="{ROOF + 2}" x2="{x(3.72):.1f}" y2="{Y(2.9):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
d.add(f'<line x1="{x(2.95):.1f}" y1="{Y(1.58):.1f}" x2="{x(2.95):.1f}" y2="{Y(0.42):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')

# Grille under the second window.
rect(5.69, 7.27, 1.36, 1.06, '#20262d', rx=1.5)
for i in range(1, 12):
    xx = x(7.27) + i * (x(5.69) - x(7.27)) / 12
    d.add(f'<line x1="{xx:.1f}" y1="{Y(1.34):.1f}" x2="{xx:.1f}" y2="{Y(1.08):.1f}" stroke="#4a525b" stroke-width="1"/>')

# Windows.
for a, b in ((3.70, 5.34), (5.70, 7.31), (7.66, 8.83), (17.77, 19.40)):
    window(a, b)
for a, b in ((11.53, 13.14), (13.46, 15.08), (15.39, 17.01)):
    window(a, b, bottom=1.23)

# Door: leaves per livery, outline and panes for all.
dx0, dx1 = x(11.15), x(9.66)
for lv, c in ((LT, LT_DOOR), (VT, VT_DOOR), (GC, GC_YELLOW)):
    d.paint(f'<rect x="{dx0:.1f}" y="{Y(2.84):.1f}" width="{dx1 - dx0:.1f}" height="{Y(0.55) - Y(2.84):.1f}" rx="3" fill="{c}"/>', lv)
d.add(f'<rect x="{dx0:.1f}" y="{Y(2.84):.1f}" width="{dx1 - dx0:.1f}" height="{Y(0.55) - Y(2.84):.1f}" rx="3" fill="none" stroke="#5b636c" stroke-width="1.6"/>')
d.add(f'<line x1="{x(10.40):.1f}" y1="{Y(2.82):.1f}" x2="{x(10.40):.1f}" y2="{Y(0.57):.1f}" stroke="#5b636c" stroke-width="1.2"/>')
for a, b in ((9.87, 10.25), (10.56, 10.94)):
    d.add(f'<rect x="{x(b):.1f}" y="{Y(2.64):.1f}" width="{x(a) - x(b):.1f}" height="{Y(0.70) - Y(2.64):.1f}" rx="3" fill="url(#glass)" stroke="#0b0d10" stroke-width="1.5"/>')
d.end()

# Roof: two equipment hoods and the exhaust stack between them (164.webp, 167.webp).
for a, b in ((4.1, 7.6), (11.3, 14.2)):
    d.add(f'<path d="M{P((a, ROOF_H - 0.02), (a + 0.25, 3.94), (b - 0.2, 3.94), (b, ROOF_H - 0.02))} Z" fill="#a3aab1" stroke="#7d858d" stroke-width="1"/>')
d.add(f'<path d="M{P((8.95, ROOF_H), (8.95, 3.84))} Q{P((8.95, 3.90), (8.80, 3.90))} L{P((8.62, 3.90), (8.62, 3.84), (8.80, 3.84), (8.80, ROOF_H))} Z" fill="#6f655c"/>')

# Bogies and the plough under the nose.
d.bogie(x(4.05), axle_m=1.9, wheel_m=0.77, top=Y(0.80), wc=Y(0.385))
d.bogie(x(20.2), axle_m=2.4, wheel_m=0.77, top=Y(0.88), wc=Y(0.385))
d.add(f'<path d="M{P((0.25, 0.42), (1.25, 0.40), (1.15, 0.20))} Q{P((0.7, 0.14), (0.35, 0.20))} Z" fill="#b6bcc2"/>')

if __name__ == '__main__':
    main(d)
