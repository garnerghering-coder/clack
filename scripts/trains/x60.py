"""SL X60 (Alstom Coradia Nordic, 6 cars, Stockholm pendeltåg). docs/TRAIN_ART.md; shared cab end in coradia.py.

Sources (all retrieved 2026-10-22):
- Side-on, cab end: järnväg.net, Södertälje hamn 2024 (Frederik Tellerup),
  https://www.jarnvag.net/images/bild/banguide/SodertaljeHamn_240721_2.jpg (1150x758). Train faces left.
- Side-on, whole cab car: järnväg.net, two X60 near Kungsängen, May 2015 (Markus Tellerup),
  https://www.jarnvag.net/images/bild/banguide/GK02426.jpg (1150x752; distant, about 7 px per metre).
- 3/4, colours and the stripes: X60 6013 Södertälje C 2024, https://www.jarnvag.net/images/bild/vagnguide/extX60_6013_SodertaljeC240721.jpg;
  X60 6071 Kungsängen 2013 (…/extX60_6071Kungsangen131011stor.jpg); X60B 6091 Stockholm 2016 (…/extX60B_6091_Stockholm160720.jpg).
- Dimensions: järnväg.net X60 page (https://www.jarnvag.net/vagnguide/x60): 107 m, 6 cars, 12 double doors a side;
  Railway Gazette 2003-09-01 (see coradia.py): doors 1300 mm, end cars 20.75 m, middle cars 16.4 m, wheels 850 mm.

Measured:
- Kungsängen photo (cab car between the nose and the gangway at u 660.5 px; a projective fit through the gangways
  at 19.84, 36.24 m and the cab door window at 2.9 m): from the gangway 2 windows, a door, 3 windows, a door, 2 windows,
  the cab door. Windows 18.22-19.30, 16.63-17.68, door 14.39-16.10, windows 13.02-14.21, 11.52-12.52, 9.89-11.03,
  door 7.82-9.56, windows 6.40-7.49, 4.86-5.93 m: the X61's window grid (x61.py) within the fit's error, which grows
  smoothly from 0.1 m at the gangway to 0.5 m near the nose, except that the X61 window at 7.93-8.99 m is a door here.
  Drawn on that grid: windows 4.27-5.37, 5.95-7.05, 9.57-10.63, 11.21-12.27, 12.86-13.92, 16.44-17.54, 18.11-19.21 m;
  doors 14.27-15.83 and, centred in the gap between 7.05 and 9.57 as on the photo, 7.53-9.09 m (1.56 m outlines, the
  Norrtåg drawing's door). Windows 0.39-0.67 of body height (Norrtåg 0.383-0.663, used). Next car: window 20.58-21.68 m.
- Södertälje hamn photo (nose tip u 633, seam u 892.5 = 2.34 m: 110.9 px/m; side top y 198 at the seam, underside 548:
  350 px = 3.23 m, i.e. 108 px/m, the same scale both ways; the dark line at y 239.5 is a trim line along the side
  at 0.117, not the roof edge): the cab side window's back edge lands on 2.26 m (Norrtåg 2.27). Cab door u 923.5-1033.5
  = 2.62-3.61 m, 0.206-0.983 high (taller and wider than the cab door in both operator drawings); its window u 943-1005 =
  2.80-3.35 m, 0.286-0.583. Cab side window 0.283-0.577 (Norrtåg 0.239-0.527), back edge 2.26 m, its front edge bowed,
  from 1.81 m at the top to 1.64 m at the bottom. Front panel line 0.71 m (the drawings: 0.90), from 0.563 to 0.977.
  Blue swoosh, upper edge (m, height): (3.62, .126) (2.41, .143) (1.87, .151) (1.51, .174) (1.33, .211) (1.15, .249)
  (0.96, .303) (0.78, .369) (0.60, .437) (0.42, .511) (0.24, .609); lower edge (3.62, .269) (2.41, .271) (1.87, .283)
  (1.51, .323) (1.33, .357) (1.15, .389) (0.96, .449) (0.78, .500) (0.60, .554) (0.42, .609). It runs level across the
  cab door top and stops at the door's back edge. Grey lower nose: (0, .828) (0.42, .920) (0.65, .991). Headlight along
  the nose edge from (0.50, .568) to (0.08, .70).
  Nose silhouette (edge-filtered photo), (m, height): cab top steps up 0.04 at the seam, (2.06, -.05), (1.80, -.03),
  (1.50, .02), (1.42, .057), (1.24, .134), (0.96, .234), (0.74, .334), (0.51, .449), (0.29, .563), (0.08, .69), tip at
  (0, .75-.86). Norrtåg's drawing is fuller (bulge -0.104, and 0.1-0.24 m further forward at 0.06-0.56 high); the photo
  is the X60 itself, so its profile is drawn; below the tip the drawing's (it matches the photo there). The body side
  goes down to the underside all the way to the photo's edge at 4.66 m (Norrtåg's X62 is raised from 2.34 m, where its
  shorter cab door ends), so the cut-out over the cab bogie is drawn from 4.66 m to the drawing's 5.96 m.
- 6013 photo, a column between windows (its trim line y 250.5 = 0.117, underside 531): upper stripe 0.153-0.185, lower
  stripe 0.251-0.276; door blue from the lower stripe down to 0.99, door outline 0.275-0.97; door leaf windows
  0.346-0.62, each 0.29 of the door width, 0.17 from its edge, 0.08 apart; passenger windows 0.38-0.67 (Norrtåg's
  0.383-0.663 used). Colours: blue #0080e5 in sun, #0064c4 in shade; body #b8bdc5.
- Not drawn: roof equipment (no side-on photo shows it against a plain background). The X60B (46 of 129 units) has a dark
  front up to the roof and three top lights; this is the X60/X60A front. One unit in the 2024 Södertälje hamn photo has no
  long stripes behind the cab door; the 2013, 2015, 2016 and 2024 (6013) photos all have them, so they are drawn.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from coradia import WIN, Coradia, smooth  # noqa: E402
from lib import main  # noqa: E402

SL = 'sl'
c = Coradia([SL])
d, x, y, M, P, pt = c.d, c.x, c.y, c.M, c.p, c.pt
d.gradient('slblue', ['#1a8ff0', '#0a7ad8', '#0767bd'], stops=(0, 0.6, 1))

WINDOWS = [(4.27, 5.37), (5.95, 7.05), (9.57, 10.63), (11.21, 12.27), (12.86, 13.92), (16.44, 17.54), (18.11, 19.21)]
DOORS = [(7.53, 9.09), (14.27, 15.83)]
DOOR = (0.275, 0.97)
DOOR_BLUE = (0.251, 0.99)
LEAF_WINS = ((0.17, 0.29, 0.08), (0.346, 0.62))


def stripes(x0, x1):
    d.add(f'<path d="M{x0:.1f},{y(0.117):.1f} H{x1:.1f}" stroke="#3a4149" stroke-width="1.3"/>')
    for t, b in ((0.153, 0.185), (0.251, 0.276)):
        d.paint(f'<rect x="{x0:.1f}" y="{y(t):.1f}" width="{x1 - x0:.1f}" height="{y(b) - y(t):.1f}" fill="url(#slblue)"/>', SL)


# Next car, front end.
c.second_car(paint=stripes, windows=[(20.58, 21.68)])

# Cab car.
# Nose profile off the Södertälje hamn photo (the operator drawings' nose is up to 0.24 m fuller; see the docstring).
NOSE = [(2.36, 0.0), (2.28, -0.04), (2.06, -0.05), (1.80, -0.03), (1.50, 0.02), (1.42, 0.057), (1.24, 0.134), (0.96, 0.234), (0.74, 0.334), (0.51, 0.449), (0.29, 0.563), (0.08, 0.69), (0, 0.75)]
d.clip('c1', c.nose_path(NOSE, skirt=(4.66, 5.96)))
d.group('c1')
d.add(f'<rect x="{d.REAR}" y="{d.ROOF - 16}" width="{d.TIP - d.REAR + 10}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{d.REAR}" y="{d.ROOF}" width="{x(3.9) - d.REAR:.1f}" height="5" fill="url(#roof)"/>')
stripes(d.REAR, x(3.61))
UP = [(3.62, 0.126), (2.41, 0.143), (1.87, 0.151), (1.51, 0.174), (1.33, 0.211), (1.15, 0.249), (0.96, 0.303), (0.78, 0.369), (0.60, 0.437), (0.42, 0.511), (0.24, 0.609)]
LO = [(3.62, 0.269), (2.41, 0.271), (1.87, 0.283), (1.51, 0.323), (1.33, 0.357), (1.15, 0.389), (0.96, 0.449), (0.78, 0.500), (0.60, 0.554), (0.42, 0.609)]
up = [pt(*q) for q in UP] + [pt(-0.3, 0.75)]
lo = [pt(*q) for q in LO] + [pt(0.15, 0.70), pt(-0.3, 0.80)]
d.paint(f'<path d="M{up[0][0]:.1f},{up[0][1]:.1f} {smooth(up)} L{lo[-1][0]:.1f},{lo[-1][1]:.1f} {smooth(lo[::-1])} Z" fill="url(#slblue)"/>', SL)
low = [pt(-0.2, 0.82), pt(0, 0.828), pt(0.42, 0.92), pt(0.65, 0.991), pt(0.8, 1.06)]
d.paint(f'<path d="M{low[0][0]:.1f},{low[0][1]:.1f} {smooth(low)} L{x(-0.3):.1f},{y(1.06):.1f} Z" fill="#5b6b7c"/>', SL)
for a, b in DOORS:
    d.paint(f'<rect x="{x(b) + 1:.1f}" y="{y(DOOR_BLUE[0]):.1f}" width="{(b - a) * M - 2:.1f}" height="{y(DOOR_BLUE[1]) - y(DOOR_BLUE[0]):.1f}" fill="url(#slblue)"/>', SL)
for a, b in WINDOWS:
    d.windows(x(b), x(a), 1, *WIN)
for a, b in DOORS:
    c.door2(a, b, *DOOR, LEAF_WINS)
d.door(x(3.61), 0.99 * M, 0.206, 0.983, win=(0.263, 0.818, 0.286, 0.583))
c.seam()
d.add(f'<path d="M{x(2.34):.1f},{y(0.117):.1f} H{x(3.61):.1f}" stroke="#3a4149" stroke-width="1.3"/>')
c.cab_window(back=2.26, top=0.283, bottom=0.577, top_front=1.81, front=1.64, knee=0.577, bulge=0.06)
c.front_panel(m=0.71, top=0.563, bottom=0.977)
hl = [pt(0.50, 0.568), pt(0.08, 0.70)]
d.add(f'<path d="M{hl[0][0]:.1f},{hl[0][1]:.1f} L{hl[1][0]:.1f},{hl[1][1]:.1f}" stroke="#4b4f55" stroke-width="7" stroke-linecap="round"/>')
d.add(f'<path d="M{hl[0][0]:.1f},{hl[0][1]:.1f} L{hl[1][0]:.1f},{hl[1][1]:.1f}" stroke="#f7f9fb" stroke-width="4.4" stroke-linecap="round"/>')
d.end()
c.running_gear()

COMMENT = '// SL X60, side view to scale. Generated by scripts/trains/x60.py (sources and measurements there and in coradia.py); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'X60.tsx')
if __name__ == '__main__':
    main(d, 'X60Side', COMMENT, OUT)
