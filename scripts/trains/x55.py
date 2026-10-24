"""SJ X55 "SJ 3000" (Bombardier Regina, 4 cars), the A cab car (X55A 33xx, first class) in SJ's livery.
docs/TRAIN_ART.md; style as x3.py. Drawn: X55A whole, cab facing right, and the coupled end of X55M.

Livery: SJ silver with a black window band. The same scheme on every dated photo from 2012 to 2026 (3351 Kiruna 2012,
3359 Stockholm 2012, 3351 Malmö 2013, 3355 Burlöv 2014, 3360 Hedemora 2016, 3355 Uppsala 2024, 3755 Hallsberg 2024,
3758 Kristinehamn 2024, Stockholm C 2026-02-27); the X55s have not been repainted.
SJ decided in summer 2026 to modernise them from autumn 2026 (järnväg.net); no new exterior is shown anywhere yet.

Sources (all retrieved 2026-10-22):
- Side-on photo, the measuring source: järnväg.net "Gävle C ... Ett X55-tåg (SJ 3000)", Frederik Tellerup 2014,
  https://www.jarnvag.net/images/bild/banguide/Gavle140803stor2.jpg (2000 x 1112; from /banguide/gavle-ange). The front
  13.8 m of an X55A, square to the camera on a bridge; the parapet hides the body below 568 px. Not stretched: the two
  round road signs in the frame measure 1.01 and 1.02 wide/high.
- SJ seat map of the X55 (one plan per car, to scale within each car; checked below):
  https://www.jarnvag.net/images/bild/vagnguide/X55.gif (from https://www.jarnvag.net/vagnguide/x55).
- Västtrafik "Designmanual fordon. Tåg Regina Vänertåg" 2024, p. 5, vector side elevation of the Regina cab car (the
  same source and numbers as regina.py): the cab module (nose outline, cab side window, windscreen edge, lower nose and
  its fairing), front bogie 3.86 m and wheel/rail heights.
  https://partnerportalen.vasttrafik.se/globalassets/media/dokument/partnerportalen/fordonsdesign/designmanualer/tag/designmanual-tag-regina-vanertag-2024-ver-2.01.pdf
- 3/4 photos (heights below the window band, the skirt, bogies, door, roof grilles, colours): järnväg.net
  extX55_3355_Hallsberg240826stor.jpg (3755, 2024-08-26), banguide/Uppsala240723_2stor.jpg (3355, 2024-07-23),
  extX55_3358_Kristinehamn240903stor.jpg (2024-09-03), extX55_3359_Stockholm2012MT.jpg (2012),
  banguide/StockholmC260227.jpg (2026-02-27); funet.fi railway archive, Ilkka Siissalo:
  https://ftp.funet.fi/index/railways/Sweden/EMU/se-sj-x55-burloev-180914-full.jpg (3355 at Burlöv, 2014-09-18).
- sv.wikipedia "Bombardier Regina" (action=raw): body width 3450 mm, wheels 840 mm, motor bogie axles 2700 mm, bogie
  centres 19000 mm. järnväg.net X55: 4 cars, 107.1 m, X55A + X55M + URB55 + X55B.

Scale. The X55's cab module is the Regina's: fitted to the Gävle photo (nose outline at 11 heights, the cab joint and
the cab window's four edges), the Västtrafik elevation coincides to 0.1-1.6 px (one point 3.5 px) at 47.49 px/m,
nose tip x 695.73 px, roof line y 446.36 px. Everything below is in metres from the nose tip at that scale.
- The seat map is to scale within the car: mapped onto the Gävle photo, 11 window and door edges sit within 2.4 px of
  one line (1.2435 Gävle px per map px), and on the Uppsala photo the cross-ratio of band end, door edges and rear end
  is 3.377 against the map's 3.368. So the map gives the rear half: metres = 0.026184 x map px - 0.5849.
- That makes the car 28.56 m from nose tip to rear end, 2 m longer than the regional Regina cab car (26.55 m). Checks:
  the Burlöv photo's four wheel positions give 18.98 m between this car's bogie centres (19.0 m), and the cross-ratio
  of the gangways on the 2012 Stockholm photo gives a 28.8 m cab car with 24.8 m middle cars (107.1 m in all). No data
  sheet with the car lengths was found, so the 28.56 m rests on these measurements.
Measured (m from the nose tip; f = fraction of the body side's height, 2.895 m, down from the roof line):
- body side: roof line to the silver side's lower edge 137.5 px = 2.895 m. The lower edge is 0.95 of the window band's
  height below the band (Uppsala 0.944, Hallsberg 0.94, Burlöv 0.985); the car body's roof is 0.06 m above the cab's
  (Gävle 443.6 px against 446.4); roof/side seam y 468 px (f 0.159).
- window band 2.82 m to the rear end, f 0.370-0.690 (Gävle y 496.5-541.3; band end x 561.9), broken by the door.
  Glass f 0.419-0.666 (504-538 px), rounded. Panes: 2.85-4.52, 5.09-6.69, 7.21-8.00 (Gävle 481-560, 378-454, 316-353),
  12.17-13.02 (Gävle 75-118), then from the map 13.50-15.10, 15.62-17.19, 17.72-19.29, 19.81-21.38, 21.91-23.48,
  24.00-25.60, 26.10-27.69 (pillars 0.52 m; the band runs on over the 0.87 m end wall).
- door (the A car's one door a side, high entrance): 9.20-11.00 (Gävle 173.3-259.2), f 0.179-1.049 (top 471 px; the
  bottom 1.1 band heights below the band, Burlöv), leaves split at 10.09; dark window surround 9.39-10.78, f 0.29-0.68;
  panes 10.30-10.755 and 9.40-9.88, f 0.315-0.654; rain strip over it 9.07-11.12, f 0.164-0.186; step below to f 1.165
  (Burlöv); destination display above it in the roof edge 9.39-10.77, f 0.032-0.112, in a housing 9.20-11.00 to f 0.145.
- cab: joint 2.79 (Gävle 565.6 = 2.74); side window frame 1.594-2.283, f 0.258-0.604, glass 1.627-2.240, f 0.272-0.594
  (Gävle 587.3-620 x 481.9-529.4); camera pod at the top of the joint 2.23-2.56, f 0.174-0.231. The nose outline, the
  black windscreen edge, the side lamp and the lower nose with its fairing are the Västtrafik elevation's (converted
  f x 3.09/2.895); its upper part is the one fitted to Gävle above.
- roof (Gävle): low dark cover 3.23-6.69 m; grille unit 5.11-6.69 (top f -0.04) with three grilles 6.60-6.29,
  6.21-5.55, 5.51-5.17, f 0.03-0.143; boxes 9.13-9.64 (f -0.112) and 10.75-10.96 (f -0.09); two insulators
  13.81-14.06 and 14.30-14.44 to f -0.19 with the roof cable from 13.81 down to the roof at 12.48. Rear roof grille
  23.25-24.70 (Uppsala and Burlöv, through the map), drawn like the front one.
- below the side: dark skirt (equipment covers) 5.47-20.60 m to f 1.228 (Uppsala and Burlöv, 3.555 m below the roof)
  with a light strip along its top; bogie centres 3.86 m (Västtrafik) and 22.86 m (19.0 m, Burlöv), axles 2.7 m, wheels
  0.84 m, wheel centres 3.637 m below the roof (Västtrafik): f 1.256, rail f 1.401. The photos show the bogie frame over
  the top of the wheels and only their lower part below it (about 0.3 m of the 0.84 m, Hallsberg).
- X55M (the sliver): band to its end, end wall 0.86 m, then glass (the seat map draws it like X55A's rear end);
  gangway 0.2 m (Västtrafik).
Colours sampled from the 2024 photos: silver body (light on top, darker low down), band near black, skirt dark grey.
Not drawn: the pantograph (on this car, behind the insulators, but out of the side-on frame and only seen at an angle),
the small aerials over the door, the louvres in the skirt (only seen at an angle), logos, numbers and lettering.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

SJ = 'sj'
H_M = 2.895
VT = 3.09 / H_M  # Västtrafik elevation's f (body side 3.09 m) to this drawing's f
d = Drawing(car_m=28.56, body_m=H_M, show_second_m=1.6, gangway_m=0.2, liveries=[SJ], roof=46)
x, y, M, ROOF, BASE, TIP, REAR, S = d.x, d.y, d.M, d.ROOF, d.BASE, d.TIP, d.REAR, d.SECOND_END
d.viewbox = lambda: f'{d.VB_X:.0f} 22 {d.TIP + 8 - d.VB_X:.0f} 188'  # roof gear to 0.55 m up, rails 4.06 m down

d.gradient('sjsilver', ['#e2e5e8', '#ccd0d4', '#a8adb3'], stops=(0, 0.5, 1))
d.gradient('sjroof', ['#b4b9bf', '#dadde1'])
BAND = '#15181c'
SKIRT = '#3b3f45'
CAR_ROOF = -0.020
WHEEL_F, RAIL_F = 1.256, 1.401


def P(*pts, vt=False):
    """(m, f) pairs to drawing 'x,y'; vt=True when f is the Västtrafik elevation's."""
    return ' '.join(f'{x(m):.1f},{y(f * VT if vt else f):.1f}' for m, f in pts)


def rect(m_front, m_rear, top, bottom, fill, rx=2, only=None, extra=''):
    d.add(f'<rect x="{x(m_rear):.1f}" y="{y(top):.1f}" width="{x(m_front) - x(m_rear):.1f}" height="{y(bottom) - y(top):.1f}" rx="{rx}" fill="{fill}"{extra}/>', only)


PANES = [(2.85, 4.52), (5.09, 6.69), (7.21, 8.00), (12.17, 13.02), (13.50, 15.10), (15.62, 17.19), (17.72, 19.29), (19.81, 21.38),
         (21.91, 23.48), (24.00, 25.60), (26.10, 27.69)]
GLASS = (0.419, 0.666)
BAND_F = (0.370, 0.690)


def pane(a, b):
    """A pane: glass in the black band (SJ), or framed on the bare body (unpainted)."""
    rect(a, b, GLASS[0] - 0.022, GLASS[1] + 0.022, '#0b0d10', rx=4, only='plain')
    rect(a, b, *GLASS, 'url(#glass)', rx=4)


def bogie(cm):
    """X55 bogie as the photos show it: the frame over the top of the wheels, only their lower part below it."""
    cx, s, r, wy = x(cm), 1.35 * M, 0.42 * M, y(WHEEL_F)
    for o in (-s, s):
        d.add(f'<circle cx="{cx + o:.1f}" cy="{wy:.1f}" r="{r:.1f}" fill="#1b1f25" stroke="#4d5560" stroke-width="2"/>')
    top, bot = y(1.03), wy + 0.12 * M
    d.add(f'<rect x="{cx - s - 0.42 * M:.1f}" y="{top:.1f}" width="{2 * s + 0.84 * M:.1f}" height="{bot - top:.1f}" rx="4" fill="#2a2f36" stroke="#3f464f" stroke-width="1.2"/>')
    for o in (-s, s):
        d.add(f'<rect x="{cx + o - 6:.1f}" y="{wy - 6:.1f}" width="12" height="11" rx="2" fill="#4a515a"/>')
    d.add(f'<line x1="{cx - 0.5 * M:.1f}" y1="{top + 9:.1f}" x2="{cx + 0.5 * M:.1f}" y2="{top + 4:.1f}" stroke="#6d7681" stroke-width="2.4" stroke-linecap="round"/>')


# ---- Bogies and the underframe first: the body and its skirt cover their tops. ----
d.add(f'<rect x="{REAR + 4}" y="{BASE}" width="{x(1.9) - REAR - 4:.1f}" height="{y(1.07) - BASE:.1f}" fill="#22262b"/>')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{BASE}" width="{S - 4 - d.VB_X + 10:.1f}" height="{y(1.07) - BASE:.1f}" fill="#22262b"/>')
for c in (3.86, 22.86):
    bogie(c)

# ---- X55M, the coupled end. ----
d.clip('c2', f'M{d.VB_X - 10},{y(CAR_ROOF):.1f} H{S - 6} Q{S},{y(CAR_ROOF):.1f} {S},{y(CAR_ROOF) + 6:.1f} V{BASE} H{d.VB_X - 10} Z')
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF - 4}" width="{S - d.VB_X + 10}" height="{d.H + 4}" fill="url(#body)"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF - 4}" width="{S - d.VB_X + 10}" height="{d.H + 4}" fill="url(#sjsilver)"/>', SJ)
d.add(f'<rect x="{d.VB_X - 10}" y="{ROOF - 4}" width="{S - d.VB_X + 10}" height="{y(0.159) - ROOF + 4:.1f}" fill="url(#roof)"/>', 'plain')
d.paint(f'<rect x="{d.VB_X - 10}" y="{ROOF - 4}" width="{S - d.VB_X + 10}" height="{y(0.159) - ROOF + 4:.1f}" fill="url(#sjroof)"/>', SJ)
d.add(f'<line x1="{d.VB_X - 10}" y1="{y(0.159):.1f}" x2="{S}" y2="{y(0.159):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
d.paint(f'<rect x="{d.VB_X - 10}" y="{y(BAND_F[0]):.1f}" width="{S - d.VB_X + 10}" height="{y(BAND_F[1]) - y(BAND_F[0]):.1f}" fill="{BAND}"/>', SJ)
d.add(f'<rect x="{S - 2.46 * M:.1f}" y="{y(GLASS[0] - 0.022):.1f}" width="{1.6 * M:.1f}" height="{y(GLASS[1] + 0.022) - y(GLASS[0] - 0.022):.1f}" rx="4" fill="#0b0d10"/>', 'plain')
d.add(f'<rect x="{S - 2.46 * M:.1f}" y="{y(GLASS[0]):.1f}" width="{1.6 * M:.1f}" height="{y(GLASS[1]) - y(GLASS[0]):.1f}" rx="4" fill="url(#glass)"/>')
d.end()
d.gangway()

# ---- X55A, the cab car. ----
nose = (
    f'L{P((2.79, 0.0), (2.781, 0.0), (2.56, 0.0), (2.364, 0.002), (2.148, 0.007), (1.964, 0.019), (1.802, 0.037), (1.669, 0.057), (1.532, 0.084), (1.417, 0.111), vt=True)} '
    f'C{P((1.219, 0.163), (1.02, 0.24), (0.842, 0.315), vt=True)} C{P((0.615, 0.409), (0.429, 0.482), (0.271, 0.586), vt=True)} '
    f'C{P((0.228, 0.618), (0.18, 0.65), (0.135, 0.683), vt=True)} C{P((0.067, 0.729), (0.026, 0.778), (0.026, 0.778), vt=True)} '
    f'L{P((0.0, 0.805), (0.005, 0.881), (0.026, 0.933), (0.12, 1.0), (1.88, 1.0), vt=True)}'
)
body = f'M{REAR},{BASE} V{y(CAR_ROOF) + 6:.1f} Q{REAR},{y(CAR_ROOF):.1f} {REAR + 6},{y(CAR_ROOF):.1f} H{x(2.79):.1f} {nose} L{P((1.95, 1.0))} Z'
d.clip('c1', body)
d.group('c1')
d.add(f'<rect x="{REAR}" y="{ROOF - 6}" width="{TIP - REAR + 10}" height="{y(1.1) - ROOF + 6:.1f}" fill="url(#body)"/>')
d.paint(f'<rect x="{REAR}" y="{ROOF - 6}" width="{TIP - REAR + 10}" height="{y(1.1) - ROOF + 6:.1f}" fill="url(#sjsilver)"/>', SJ)
# Roof shoulder down to the roof/side seam (the cab's roof curves on down the nose).
d.add(f'<rect x="{REAR}" y="{ROOF - 6}" width="{x(2.79) - REAR:.1f}" height="{y(0.159) - ROOF + 6:.1f}" fill="url(#roof)"/>', 'plain')
d.paint(f'<rect x="{REAR}" y="{ROOF - 6}" width="{x(2.79) - REAR:.1f}" height="{y(0.159) - ROOF + 6:.1f}" fill="url(#sjroof)"/>', SJ)
d.add(f'<line x1="{REAR}" y1="{y(0.159):.1f}" x2="{x(2.79):.1f}" y2="{y(0.159):.1f}" stroke="#000" stroke-opacity="0.15" stroke-width="1.2"/>')
# SJ: the black window band, front and rear of the door.
for a, b in ((2.82, 9.20), (11.00, 28.7)):
    rect(a, b, *BAND_F, BAND, rx=3, only=SJ)
for a, b in PANES:
    pane(a, b)
# Door: outline, split, the dark surround with its two panes; rain strip; destination display in its housing.
rect(9.20, 11.00, -0.02, 0.145, 'none', rx=3, extra=' stroke="#000" stroke-opacity="0.18" stroke-width="1.2"')
rect(9.39, 10.77, 0.032, 0.112, '#101317', rx=1.5)
rect(9.07, 11.12, 0.164, 0.186, '#2f343a', rx=1)
d.door(x(11.00), x(9.20) - x(11.00), 0.179, 1.049)
d.add(f'<line x1="{x(10.09):.1f}" y1="{y(0.179) + 2:.1f}" x2="{x(10.09):.1f}" y2="{y(1.049) - 2:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
rect(9.39, 10.78, 0.29, 0.68, '#2b3036', rx=4)
for a, b in ((9.40, 9.88), (10.30, 10.755)):
    rect(a, b, 0.315, 0.654, 'url(#glass)', rx=3)
# Cab: joint, side window, camera pod; the windscreen's black edge and the side lamp at the nose.
d.add(f'<line x1="{x(2.79):.1f}" y1="{ROOF + 1}" x2="{x(2.79):.1f}" y2="{BASE}" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
rect(1.594, 2.283, 0.258, 0.604, '#0b0d10', rx=5)
rect(1.627, 2.240, 0.272, 0.594, 'url(#glass)', rx=4)
rect(2.23, 2.56, 0.174, 0.231, '#5d636b', rx=2)
d.add(
    f'<path d="M{P((0.596, 0.588), vt=True)} L{P((0.283, 0.586), vt=True)} C{P((0.228, 0.618), (0.180, 0.650), (0.135, 0.683), vt=True)} '
    f'C{P((0.067, 0.729), (0.026, 0.778), (0.026, 0.778), vt=True)} C{P((0.109, 0.771), (0.179, 0.756), (0.179, 0.756), vt=True)} '
    f'C{P((0.297, 0.729), (0.476, 0.638), (0.596, 0.588), vt=True)} Z" fill="#464646"/>'
)
d.add(
    f'<path d="M{P((0.285, 0.596), vt=True)} L{P((0.549, 0.596), vt=True)} C{P((0.549, 0.596), (0.360, 0.680), (0.276, 0.713), vt=True)} '
    f'C{P((0.225, 0.732), (0.153, 0.755), (0.116, 0.761), vt=True)} C{P((0.078, 0.768), (0.049, 0.768), (0.049, 0.768), vt=True)} '
    f'C{P((0.124, 0.706), (0.178, 0.667), (0.285, 0.596), vt=True)} Z" fill="#0b0d10"/>'
)
d.add(f'<ellipse cx="{x(0.10):.1f}" cy="{y(0.86 * VT):.1f}" rx="2.5" ry="4" fill="#f7f9fb" stroke="#4b4f55" stroke-width="1"/>')
d.end()

# Skirt between the bogies, with its light top strip; door step; the fairing under the nose.
rect(5.47, 20.60, 1.0, 1.228, SKIRT, rx=3)
rect(5.47, 20.60, 1.0, 1.012, '#9aa1a8', rx=0)
rect(9.20, 11.00, 1.049, 1.165, '#2f343a', rx=2)
d.add(
    f'<path d="M{P((1.88, 1.0), vt=True)} L{P((0.12, 1.0), vt=True)} C{P((0.11, 1.10), (0.30, 1.20), (0.565, 1.22), vt=True)} '
    f'L{P((1.59, 1.228), vt=True)} C{P((1.70, 1.12), (1.80, 1.05), (1.88, 1.0), vt=True)} Z" fill="#454b52"/>'
)

# Roof gear (Gävle): low cover, grille unit (and the rear grille), boxes, insulators and the roof cable.
rect(3.23, 6.69, -0.047, 0.004, '#5b6168', rx=2)
for front, rear, grilles in ((5.11, 6.69, ((5.17, 5.51), (5.55, 6.21), (6.29, 6.60))), (23.25, 24.70, ((23.31, 23.62), (23.66, 24.30), (24.38, 24.64)))):
    rect(front, rear, -0.04, 0.155, '#b8bec5', rx=3, extra=' stroke="#8a929b" stroke-width="0.8"')
    for a, b in grilles:
        rect(a, b, 0.03, 0.143, '#3a4048', rx=1.5)
rect(9.13, 9.64, -0.112, -0.015, '#4a5058', rx=1.5)
rect(10.75, 10.96, -0.09, -0.015, '#8e98a3', rx=1.5)
for a, b in ((13.81, 14.06), (14.30, 14.44)):
    cx, w = (x(a) + x(b)) / 2, x(a) - x(b)
    d.add(f'<rect x="{cx - 1.5:.1f}" y="{y(-0.19):.1f}" width="3" height="{y(-0.015) - y(-0.19):.1f}" fill="#3b4148"/>')
    for k in range(4):
        d.add(f'<rect x="{cx - w / 2:.1f}" y="{y(-0.165 + k * 0.04):.1f}" width="{w:.1f}" height="2.6" rx="1.3" fill="#3b4148"/>')
d.add(f'<path d="M{P((13.81, -0.18))} C{P((13.4, -0.17), (13.0, -0.05), (12.48, -0.03))}" fill="none" stroke="#2f343a" stroke-width="2" stroke-linecap="round"/>')

if __name__ == '__main__':
    main(d)
