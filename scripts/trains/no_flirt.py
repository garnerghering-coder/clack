"""Norway Type 74 / Type 75 (Stadler FLIRT, 5 cars, run by Vy). docs/TRAIN_ART.md; x3.py is the worked example.

Drawn: the BMa cab car (cab facing right) and the end of BPa. Type 74 and 75 have the same BMa from the side (same
doors, windows and nose in Norske tog's elevations of BMa74 and BMa75, which differ only in drawing scale, 0.966), so
one drawing serves both. They differ on the other cab car (BMb74 has one door a side, BMb75 two) and inside.

Sources (retrieved 2026-10-22):
- Norske tog (owner of the fleet) side elevations, to scale, one SVG per car:
  https://www.norsketog.no/uploads/trains/filled/motor-coach/Type74/type74_BMa74.svg, type74_BMb74.svg, type74_BPa74.svg,
  .../Type75/type75_BMa75.svg (pages https://www.norsketog.no/tog/motorvognsett/type-74 and /type-75).
- Side-on photo, current Vy livery: Norske tog's photo of BMb 74520 (cab on the left, the other side of the train),
  https://www.norsketog.no/imager/images/Tog/2545/Vy_tog_VY_01745b_7abbbb2796f27c91ef535646dc2c5299.jpg
- 3/4 photos, Vy livery: jarnvag.net BM74 page, https://www.jarnvag.net/images/bild/banguide/Trollhattan260618stor.jpg
  (74527, cab on the right, 2026-06) and .../vagnguide/extBM74_28_Oslo221211_stor.jpg (74528, 2022-12-11); front:
  Wikimedia Commons "FLIRT Type 75-09 Vy colors at Oslo S.jpg".
- no.wikipedia "Type 74 (motorvognsett)" / "Type 75 (motorvognsett)": 105.5 m, 5 cars, height 4380 mm, wheels 920 mm,
  bogie centres 16 800-18 300 mm, axle spacing 2500-2750 mm; 74: 9 door pairs, 75: 10; pantograph car BPb (car 4).

Scale of the BMa74 elevation: 74.4 px/m, checked four ways: rail (y 449) to cab roof (122.8) 326 px = 4.38 m; motor
bogie axles 185.2 px = 2.49 m (2.5); Jacobs bogie axles 205.4 px = 2.76 m (2.75); bogie centres 1247 px = 16.8 m.
Elevation px (BMa74): nose tip x 1584.1, roof line y 128.7, body underside y 411.6 (3.80 m), rear body end x 0.8
(car 21.28 m), gangway 38.2 px (0.51 m).
- windows (x from the rear): 58.4-174.5 high (y 233.0-304.3), 362.5-478.6 tall (233.7-331.2), 516.7-632.8 low
  (260.1-331.4), 670.2-786.3 tall, 975.0-1091.1 high. The elevation paints the top 27 px of the tall windows body
  colour; photos (Oslo 74528) show them glazed full height, so they're drawn glazed.
- doors 209.3-325.4 and 822.6-938.7 (y 214.3-396.0), two leaves, leaf windows 0.132-0.372 / 0.627-0.866 of the door
  width, y 230.4-331.2; steps below the doors y 406.4-416.1.
- cab side window (black D shape 1387.8-1484.1, glass 1393.9-1434.6 x 233.0-304.3), cab joint x 1377.9,
  roof/side seam y 185.9, roof covers 763.5-928.2 and 1083-1375.2 (y 123.2), roof grilles as listed in ROOF_GRILLES.
- bogies: Jacobs at x -17.6 (axles 2.75 m), motor bogie under the cab at 1229.5 (2.5 m); wheel centres y 413.8.
- BPa end (BPa74 elevation, same scale, its x 1548.2 = BMa x -37.0): roof y 140 stepping down to 154.9 over the last
  74 px, roof fitting at its x 1485-1539, underside 401.2.
Vy livery, read off the side photo of 74520 and mapped onto the elevation through the door (photo door 248-437 px =
elevation 214.1-395.8, 1.04 px per px) and the first window and door edges (0.90 px per px):
- dark grey body, green cab end; the edge is one straight line, from 58 % across the first window (from its front edge)
  at the top of the side to 19 % across at the bottom: elevation (1024.2, 178.5) to (1072.5, 411.6). (Norske tog's own
  drawing shades a similar diagonal, (1000, 124) to (1081.5, 416); the photo is used.)
- the press photo's first window looks 0.13 m deeper than the elevation's; Oslo 74528, Trollhattan 74527 and MTRX
  X74 006 (jarnvag.net, same body) all put its bottom where the elevation does, so the elevation is kept.
Overlay checks (scratchpad): on the elevation every edge coincides; on the mirrored photo of 74520 the paint edge,
silver roof, door, door windows, pinstripe heights and wheels coincide (the photo's nose is turned to the camera).
- silver roof down to y 178.5 behind the cab joint; the cab is green up to the windscreen.
- door leaves green, on every door.
- two white pinstripes, 0.05 m (y 244.9-248.8 and 321.8-325.7). On this side (cab on the right, as 74527 at Trollhattan
  shows) the upper one is the long one: from 443 px behind the nose tip back along the whole train, stopping at windows
  and doors; the lower one is a dash 207-260 px behind the tip. (On the other side the two swap, 74520.)
- the Vy logo between them is a trademark and isn't drawn.
Bogies: lib.py's bogie() (wheels behind a side frame, as the photos show), drawn before the body so the skirt hides
the wheel tops; the frame from the underside (y 373 in the arch under the cab, 401.2 under the gangway).
Not drawn: pantograph (on BPb, car 4, out of view); logo, numbers, lettering.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

VY = 'vy'
PXM = 74.4  # elevation px per metre
EN, ER, EB = 1584.1, 128.7, 411.6  # nose tip x, roof line y, body underside y (elevation px)
d = Drawing(car_m=(EN - 0.8) / PXM, body_m=(EB - ER) / PXM, gangway_m=38.2 / PXM, liveries=[VY])
M, ROOF, BASE, TIP, REAR, S = d.M, d.ROOF, d.BASE, d.TIP, d.REAR, d.SECOND_END
K = M / PXM


def ex(px):
    """Elevation x (px) to drawing x."""
    return TIP - (EN - px) * K


def ey(py):
    """Elevation y (px) to drawing y."""
    return ROOF + (py - ER) * K


def f(py):
    """Elevation y (px) as a fraction of body height, for the kit's windows/doors."""
    return (py - ER) / (EB - ER)


def epath(dstr, dx=0.0):
    """An elevation path (absolute M/L/H/V/C/Z only, as Norske tog's SVGs are) in drawing coordinates."""
    out, cmd, nums = [], None, []

    def flush():
        if cmd is None:
            return
        if cmd in 'Z':
            out.append('Z')
        elif cmd == 'H':
            out.append('H' + ' '.join(f'{ex(n + dx):.1f}' for n in nums))
        elif cmd == 'V':
            out.append('V' + ' '.join(f'{ey(n):.1f}' for n in nums))
        else:
            pts = [f'{ex(nums[i] + dx):.1f},{ey(nums[i + 1]):.1f}' for i in range(0, len(nums), 2)]
            out.append(cmd + ' '.join(pts))

    for tok in re.findall(r'[MLHVCZ]|-?\d*\.?\d+(?:e-?\d+)?', dstr):
        if tok in 'MLHVCZ':
            flush()
            cmd, nums = tok, []
        else:
            nums.append(float(tok))
    flush()
    return ''.join(out)


# Elevation outlines (BMa74 unless noted), copied from Norske tog's SVG.
BODY_UPPER = 'M1379 128.7H1374.4V123.2H1082.3V128.7H927.401V123.2H762.701V128.7H676.501L547.801 140.7H1.00078L0.800781 331.7L1295.5 333.5L1453.4 332.6C1453.4 332.6 1538.8 334.2 1578.7 338.5C1578.7 338.5 1544.1 152.4 1379.1 122.8V128.7H1379Z'
BODY_LOWER = 'M1281.5 333.7H0.800781V401.2H96.5008C101.101 401.2 102.801 403.6 102.801 403.6V409.6L104.801 411.6H1080.7C1080.7 411.6 1082.7 409.8 1085.6 407.4C1092.4 401.5 1104.4 391.5 1108.1 389.3C1126.5 378.6 1142.9 379 1142.8 378.4C1141.9 372.7 1146.5 373.4 1146.5 373.4C1146.5 373.4 1197.7 373.4 1203.2 373.4H1243.2C1243.2 373.4 1282.4 373.2 1290.5 373.2C1298.6 373.2 1294.7 379.6 1294.7 379.6C1294.7 379.6 1323.5 380.2 1327.2 382.6C1331 385.2 1354 395.9 1357.8 398.6C1360.4 400.5 1381.5 412.6 1384.4 414.3C1387.3 416 1388.9 415.9 1388.9 415.9C1388.9 415.9 1443.7 415.9 1447.1 415.9C1450.5 415.9 1451.6 414 1451.6 414C1451.6 414 1460.9 395.9 1461.7 394.1C1462.5 392.3 1464 392.6 1464 392.6C1471.7 391.1 1570.9 394.9 1572.3 394.6C1573.7 394.3 1575.6 387.2 1575.6 387.2H1565.2C1561.8 387.2 1562.4 384.6 1562.4 384.6C1564.8 378.4 1568.8 359.7 1569.5 355.7C1570.2 351.7 1574.1 352.3 1574.1 352.3H1580.8V345.5C1576.5 342.9 1572.8 337.3 1572.8 337.3C1463.9 330.5 1377.2 331.4 1377.2 331.4L1281.4 333.5L1281.5 333.7Z'
NOSE_BAND = 'M1574.9 338.4L1580.5 338.9C1580.5 338.9 1583.4 336 1584.1 335.6C1584.1 335.6 1584.4 304.3 1570.6 279.9L1560.5 276C1560.5 276 1543 238.9 1531 225.7C1519 212.5 1507.2 198.3 1501.8 192.7C1496.4 187.1 1473.4 166.9 1467.1 164.3C1467.1 164.3 1448.3 149.7 1446 148.2C1443.8 146.7 1413.1 127.8 1390.2 124.8C1390.2 124.8 1382.7 123.2 1381.6 123.3C1380.5 123.3 1378.2 122.9 1378.2 126.9V139.4C1378.2 139.4 1412.5 135.3 1455.6 158C1498.7 180.6 1528.8 226.6 1528.8 226.6C1528.8 226.6 1554.7 269 1562.4 291.1C1570.1 313.1 1573.7 321.1 1574.7 338.4H1574.9Z'
SEAM_OVERLAP = 'M0.8 325H1560V340H0.8Z'  # the two outlines meet at y 331-334 with a hairline gap; this strip closes it
CAB_WINDOW = 'M1484 297.2C1482.8 285.8 1479.6 267.7 1470.4 252.2C1461.7 237.6 1445.7 228.9 1428.7 228.7C1424.2 228.7 1421 228.7 1398.3 228.7C1392.5 228.7 1387.8 233.4 1387.8 239.1V298C1387.8 303.8 1392.5 308.4 1398.2 308.4H1473.5C1479.8 308.4 1484.7 303.2 1484 297.1V297.2Z'
HEADLIGHT = 'M1571.7 311.3C1571.7 311.3 1579.4 316.9 1580.8 319.7C1580.8 319.7 1582.5 328.5 1582.1 331.3C1582.1 331.3 1578.6 328.9 1575.3 328.1C1575.3 328.1 1574.2 318.2 1571.8 311.3H1571.7Z'
LOWER_SEAM = 'M1378.1 332.1C1378.1 332.1 1546 332.7 1580.7 339.2'
PLOUGH = 'M1493 393.2L1547.1 400.3C1547.1 400.3 1544 409.4 1553.6 419C1563.3 428.7 1572.2 434.1 1563.3 433.3C1558.1 432.8 1542.8 433.1 1530.5 433.3C1521.3 433.5 1513.8 433.8 1513.8 433.8L1455.1 408.9L1462.7 394.1C1462.7 394.1 1463.2 392.7 1465.9 392.5C1468.6 392.3 1492.9 393 1492.9 393L1493 393.2Z'
COUPLER = 'M1581.9 352.7L1602.1 354.8V385.2L1576.8 387.4H1565.4C1565.4 387.4 1562.8 387.2 1563.6 384.2C1564.5 381.2 1567.7 371.3 1568.7 365.4C1569.7 359.5 1570.7 355.1 1571 354.7C1571.3 354.3 1571.8 352.7 1575.2 352.7C1578.4 352.7 1581.8 352.7 1581.8 352.7Z'
# BPa74 (its own x; shifted by BPA_DX onto BMa's x): roof stepping down at the gangway end, and the roof fitting there.
BPA_DX = -1585.2
BPA_BODY = 'M1548.5 401.2V154.9H1494.9C1494.9 154.9 1489 154.9 1484 149.7C1479 144.5 1474.3 140 1474.3 140L1300 140L1300 401.2Z'
BPA_FITTING = 'M1521.8 150.8L1517.7 142.8L1516.2 140.8V139.7H1519.3H1528.2V147.4H1531.3V130.7H1528.1V138.7H1516.4C1516.4 138.7 1516.4 134.9 1516.4 134.8C1516.4 134.7 1513.2 134.8 1513.2 134.8V138.5H1511.7L1511.4 138.8H1495.8V130.7H1492.8V147.4H1495.7V139.4H1510.9L1509.7 140.8L1504.4 150.7H1485.1C1487.1 153.9 1492.7 154.8 1492.7 154.8H1539.4V150.7H1521.6L1521.8 150.8Z'
ROOF_GRILLES = [(359.6, 448.2, 142.8, 181.3), (707.1, 758.5, 142.8, 181.3), (828.2, 879.6, 142.8, 181.3), (1051.7, 1140.3, 142.8, 181.3),
                (1148.1, 1236.7, 142.8, 181.3), (1282.0, 1318.4, 151.3, 170.2), (1336.8, 1362.5, 142.4, 180.9)]

HIGH, LOW, TALL = (233.0, 304.3), (260.1, 331.4), (233.7, 331.2)
WINDOWS = [(58.4, 174.5, HIGH), (362.5, 478.6, TALL), (516.7, 632.8, LOW), (670.2, 786.3, TALL), (975.0, 1091.1, HIGH)]
DOORS = [209.3, 822.6]  # left edges; 116.1 px wide
DOOR_W, DOOR_Y, DOOR_WIN_Y = 116.1, (214.3, 396.0), (230.4, 331.2)
SEAM, CAB_JOINT = 185.9, 1377.9

d.gradient('vygreen', ['#167267', '#0f6157', '#0a4d45'], stops=(0, 0.55, 1))
d.gradient('vydark', ['#3b4548', '#2d3538', '#23292c'], stops=(0, 0.55, 1))
d.gradient('vyroof', ['#d4d9de', '#eef0f2'])
VY_PAINT_TOP = 178.5  # silver roof down to here (photo); the elevation's seam line is at 185.9
VY_EDGE = ((1024.2, 178.5), (1072.5, 411.6))
VY_UPPER, VY_LOWER = (244.9, 248.8), (321.8, 325.7)
VY_DASH = (EN - 260, EN - 207)  # lower dash, x range (px)
VY_LINE_FROM = EN - 443  # the long upper line runs back from here


def door(x0):
    x, w = ex(x0), DOOR_W * K
    d.paint(f'<rect x="{x:.1f}" y="{ey(DOOR_Y[0]):.1f}" width="{w:.1f}" height="{ey(DOOR_Y[1]) - ey(DOOR_Y[0]):.1f}" rx="3" fill="url(#vygreen)"/>', VY)
    d.door(x, w, f(DOOR_Y[0]), f(DOOR_Y[1]))
    d.add(f'<line x1="{x + w / 2:.1f}" y1="{ey(DOOR_Y[0]) + 1:.1f}" x2="{x + w / 2:.1f}" y2="{ey(DOOR_Y[1]) - 1:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
    for l, r in ((0.132, 0.372), (0.627, 0.866)):
        d.add(f'<rect x="{x + l * w:.1f}" y="{ey(DOOR_WIN_Y[0]):.1f}" width="{(r - l) * w:.1f}" height="{ey(DOOR_WIN_Y[1]) - ey(DOOR_WIN_Y[0]):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')


# Bogies first, so the body skirt hides the wheel tops as on the train (lib.py's style: wheels behind a side frame), to scale: wheel centres at elevation y 413.8; the frame starts
# at the body's underside there (401.2 under the gangway, 373 in the arch under the cab). Jacobs bogie axles 2.75 m,
# motor bogie 2.5 m, wheels 0.92 m.
d.bogie(ex(-17.6), axle_m=2.75, wheel_m=0.92, top=ey(401.2), wc=ey(413.8))
d.bogie(ex(1229.5), axle_m=2.5, wheel_m=0.92, top=ey(373), wc=ey(413.8))

# BPa, the end next to the cab car.
d.clip('c2', epath(BPA_BODY, BPA_DX))
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{ey(SEAM) - ROOF + 10:.1f}" fill="url(#roof)"/>')
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{ey(VY_PAINT_TOP):.1f}" width="{S - d.VB_X + 10:.1f}" height="{BASE - ey(VY_PAINT_TOP) + 10:.1f}" fill="url(#vydark)"/>', VY)
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{ey(VY_PAINT_TOP) - ROOF + 10:.1f}" fill="url(#vyroof)"/>', VY)
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{ey(VY_UPPER[0]):.1f}" width="{S - d.VB_X + 10:.1f}" height="{(VY_UPPER[1] - VY_UPPER[0]) * K:.1f}" fill="#f2f4f3"/>', VY)
d.add(f'<line x1="{d.VB_X - 10:.1f}" y1="{ey(SEAM):.1f}" x2="{S:.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>', 'plain')
d.end()
d.add(f'<path d="{epath(BPA_FITTING, BPA_DX)}" fill="#59616a"/>')

# Gangway: bellows (elevation y 187.6-400.7), the plate over it (174.4-182.7) and its rounded cover (135.5-154.6).
g0, g1 = S, REAR
d.add(f'<rect x="{g0}" y="{ey(187.6):.1f}" width="{g1 - g0}" height="{ey(400.7) - ey(187.6):.1f}" fill="#2b3037"/>')
for i in range(1, 5):
    d.add(f'<line x1="{g0 + i * (g1 - g0) / 5:.1f}" y1="{ey(190.9):.1f}" x2="{g0 + i * (g1 - g0) / 5:.1f}" y2="{ey(400.4):.1f}" stroke="#41474f" stroke-width="1.5"/>')
d.add(f'<path d="M{g0},{ey(174.4):.1f} L{g1},{ey(176.8):.1f} V{ey(182.7):.1f} L{g0},{ey(181.7):.1f} Z" fill="#3a4048"/>')
d.add(f'<path d="M{g0},{ey(154.6):.1f} A{(g1 - g0) / 2:.1f},{ey(154.6) - ey(135.5):.1f} 0 0 1 {g1},{ey(154.6):.1f} Z" fill="#3a4048"/>')

# Cab car: its outline is the elevation's upper body, lower body (skirt and bogie arch) and nose band together.
d.defs['c1'] = f'<clipPath id="c1"><path d="{epath(BODY_UPPER)}"/><path d="{epath(BODY_LOWER)}"/><path d="{epath(NOSE_BAND)}"/><path d="{epath(SEAM_OVERLAP)}"/></clipPath>'
d.group('c1')
d.add(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{TIP - REAR + 14}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{ex(CAB_JOINT) - REAR + 2:.1f}" height="{ey(SEAM) - ROOF + 10:.1f}" fill="url(#roof)"/>')
# Vy: dark body, silver roof, green cab end behind one straight edge.
(ax, ay), (bx, by) = VY_EDGE
slope = (bx - ax) / (by - ay)
d.paint(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{TIP - REAR + 14}" height="{d.H + 20}" fill="url(#vydark)"/>', VY)
d.paint(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{ex(CAB_JOINT) - REAR + 2:.1f}" height="{ey(VY_PAINT_TOP) - ROOF + 10:.1f}" fill="url(#vyroof)"/>', VY)
d.paint(
    f'<path d="M{ex(ax):.1f},{ey(ay):.1f} L{ex(bx + slope * 12):.1f},{ey(by + 12):.1f} H{TIP + 12} V{ROOF - 10} H{ex(CAB_JOINT):.1f} V{ey(ay):.1f} Z" fill="url(#vygreen)"/>',
    VY,
)
d.paint(f'<rect x="{REAR - 2}" y="{ey(VY_UPPER[0]):.1f}" width="{ex(VY_LINE_FROM) - REAR + 2:.1f}" height="{(VY_UPPER[1] - VY_UPPER[0]) * K:.1f}" fill="#f2f4f3"/>', VY)
d.paint(f'<rect x="{ex(VY_DASH[0]):.1f}" y="{ey(VY_LOWER[0]):.1f}" width="{(VY_DASH[1] - VY_DASH[0]) * K:.1f}" height="{(VY_LOWER[1] - VY_LOWER[0]) * K:.1f}" fill="#f2f4f3"/>', VY)
# Seams: roof/side (unpainted only; on Vy the paint edge sits there), the cab joint and the cab's lower seam.
d.add(f'<line x1="{REAR}" y1="{ey(SEAM):.1f}" x2="{ex(CAB_JOINT):.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>', 'plain')
d.add(f'<line x1="{ex(CAB_JOINT):.1f}" y1="{ey(123):.1f}" x2="{ex(CAB_JOINT):.1f}" y2="{ey(409):.1f}" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
d.add(f'<path d="{epath(LOWER_SEAM)}" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
for x0, x1, y0, y1 in ROOF_GRILLES:
    d.add(f'<rect x="{ex(x0):.1f}" y="{ey(y0):.1f}" width="{(x1 - x0) * K:.1f}" height="{(y1 - y0) * K:.1f}" rx="1.5" fill="#a3aab2" stroke="#8a929b" stroke-width="0.8"/>')
for x0, x1, (t, b) in WINDOWS:
    d.windows(ex(x0), ex(x1), 1, f(t), f(b))
for x0 in DOORS:
    door(x0)
# Windscreen band down the nose, cab side window, headlight.
d.add(f'<path d="{epath(NOSE_BAND)}" fill="#14181e"/>')
d.add(f'<path d="{epath(CAB_WINDOW)}" fill="#0b0d10"/>')
d.add(f'<rect x="{ex(1393.9):.1f}" y="{ey(233.0):.1f}" width="{(1434.6 - 1393.9) * K:.1f}" height="{(304.3 - 233.0) * K:.1f}" rx="3" fill="url(#glass)"/>')
d.add(f'<path d="{epath(HEADLIGHT)}" fill="#f7f9fb" stroke="#4b4f55" stroke-width="0.8"/>')
d.end()

# Door steps, snowplough and coupler.
for x0 in DOORS:
    d.add(f'<rect x="{ex(x0):.1f}" y="{ey(406.4):.1f}" width="{DOOR_W * K:.1f}" height="{(416.1 - 406.4) * K:.1f}" fill="#3a4450"/>')
d.add(f'<path d="{epath(PLOUGH)}" fill="#3b4148"/>')
d.add(f'<path d="{epath(COUPLER)}" fill="#2a2f36"/>')

COMMENT = '// Norway Type 74/75 (Stadler FLIRT, BMa cab car), side view to scale. Generated by scripts/trains/no_flirt.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'NoFlirt.tsx')
if __name__ == '__main__':
    main(d, 'NoFlirtSide', COMMENT, OUT)
