"""Sweden X74 (Stadler FLIRT Nordic, 5 cars, VR Sverige; ex MTR Express). docs/TRAIN_ART.md; x3.py is the worked example.

Who runs it: MTR sold MTR Express to VR (Finland) in spring 2024; VR took over the Stockholm-Göteborg trains in August
2024 and wrapped all six sets (X74 001-006) in VR green and white (jarnvag.net X74 page, retrieved 2026-10-22).
Drawn: the cab car (cab facing right; the side seen in photo 64, the other side's stripes lean the other way, see
below) and the end of car 2; liveries `vr` and unpainted.

Sources (retrieved 2026-10-22/23):
- Garner's photos (images/64-67.webp): 64 = 74001 "Estelle" at Stockholm C, side-on close-up of the cab end (2000 px,
  cab right); 65 = the cab car side-on at Stockholm C (1024 px, cab left); 66 = a set at speed; 67 = 3/4 front
  (the same photo as jarnvag.net's X74 001 at Töreboda 2024-09-03).
- Flickr, X74 001 at Segerstad, 2024-09-21, https://www.flickr.com/photos/194330441@N03/54025140627 (2048 px, cab right,
  whole cab car).
- Norske tog's side elevation of BMa74 (https://www.norsketog.no/uploads/trains/filled/motor-coach/Type74/type74_BMa74.svg,
  BPa74 for car 2): same FLIRT Nordic body (jarnvag.net: "X74 ... är av samma typ" as BM74), scale checked in
  no_flirt.py (74.4 px/m). Positions below are in its px ("E").
- MTR Express floor plan (jarnvag.net, Översiktsritning X74): one door pair in the cab car.

Body: the cab, the first window, the door and the next two windows are BMa74's. Photo 65 (mirrored, 59.5 px/m, fitted on
the cab joint and door, within 0.02 m near the cab) puts the window ahead of the door at E 973.7-1092.6 (BMa74
975-1091.1) and the next windows at 782 and 625 (BMa74 786.3 and 632.8). Behind that the X74 differs (Segerstad photo,
rectified onto the elevation by a homography on window and door-window corners, residuals 0.4-6 px, under 0.08 m):
- the window at E 358.5-477.6 is low (y 259-334), not tall as on BMa74;
- where BMa74 has its rear door there is a low window, E 201.4-322.8 (drawn 204.0-320.1, BMa74's window width);
- then BMa74's high window (measured 51.2-168.7, BMa74 58.4-174.5) and the car end. Töreboda shows the same row of
  windows: tall, low, low, low, high.
- cab side window: a rounded rectangle, E 1389-1434 x 232-307 (photo 65); BMa74's is D-shaped.
- hatch below it, E 1256-1320 x 255-328, with two grilles 1275-1303 x 267-282 and 300-314; camera box 1299-1322 x
  218-237 (photo 64 on local anchors, checked on the rectified Segerstad photo, within 10 px).
- roof: a grey roof module from the roof line down to the side seam (y 185.9), E 1302-1378 (photos 64 and 65), with
  BMa74's louvre at 1336.8-1362.5; on the roof shoulder (y 145-176) a louvre grille 604-719 and grille panels 285-360,
  746-822, 832-906, 914-982, 1027-1064, 1110-1180, 1190-1227, 1251-1302 (rectified Segerstad; the roof is off the side
  plane, so these are good to about 0.15 m). The panels are red on the VR trains.
Livery `vr` (photos 64, 65, Segerstad, Töreboda; colours from the sunlit Segerstad photo): green #0bb553 with
cream-white #eef0ea speed lines on a 0.127 m pitch (9.45 E px; rows centred at y 237.9 + 9.45 k, k = -5..17, measured
on photo 64, 7.5 pitches per window height). Each row is one band whose white share changes along the car; the
change points are straight slanted lines x = x280 + s (y - 280) (E px, measured on the rectified Segerstad photo):
  b0 white tips (green in front)       x280 1133.5  s -0.60  (photo 64: -0.60)
  b1 thin to thick (ramp 100 px)       x280  943    s -1.30  (mostly under the green door)
  b2 green tips, white from here       x280  795    s -0.78
  b3 green tips again (rear)           x280  535    s -0.83
  b4 thick to thin green (ramp 100 px) x280  305    s -0.82
  b5 white tips, green behind          x280   88    s -0.83
  White share: 0 / 0.225 (photo 64: 7 px of 31) / 0.75 / 1 / 0.75 / 0.225 / 0, tips tapering over 12 px (photo 64).
  The door leaves are green; the cab module and the end of car 2 are green, car 2's white lines starting from tips on
  the same slope as b5. The paint starts at the side seam (y 185.9); the roof is grey.
  The pattern is not mirrored between the train's two sides (the tip line leans the same way in the image on both, in
  photos 64 and 65), so the other side's drawing would differ; this is the side photo 64 shows.
Overlays (scratchpad): the plain drawing on the rectified Segerstad photo and on photo 64, the vr drawing on both.
Not drawn: VR logo, train name, numbers, lettering; the small hatch below the logo and the round caps (too faint);
red step markings under the door and arch; pantograph (not on these two cars' visible ends).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

VR = 'vr'
PXM = 74.4
EN, ER, EB = 1584.1, 128.7, 411.6
d = Drawing(car_m=(EN - 0.8) / PXM, body_m=(EB - ER) / PXM, gangway_m=38.2 / PXM, liveries=[VR])
M, ROOF, BASE, TIP, REAR, S = d.M, d.ROOF, d.BASE, d.TIP, d.REAR, d.SECOND_END
K = M / PXM


def ex(px):
    return TIP - (EN - px) * K


def ey(py):
    return ROOF + (py - ER) * K


def f(py):
    return (py - ER) / (EB - ER)


def epath(dstr, dx=0.0):
    """An elevation path (absolute M/L/H/V/C/Z only) in drawing coordinates."""
    out, cmd, nums = [], None, []

    def flush():
        if cmd is None:
            return
        if cmd == 'Z':
            out.append('Z')
        elif cmd == 'H':
            out.append('H' + ' '.join(f'{ex(n + dx):.1f}' for n in nums))
        elif cmd == 'V':
            out.append('V' + ' '.join(f'{ey(n):.1f}' for n in nums))
        else:
            out.append(cmd + ' '.join(f'{ex(nums[i] + dx):.1f},{ey(nums[i + 1]):.1f}' for i in range(0, len(nums), 2)))

    for tok in re.findall(r'[MLHVCZ]|-?\d*\.?\d+(?:e-?\d+)?', dstr):
        if tok in 'MLHVCZ':
            flush()
            cmd, nums = tok, []
        else:
            nums.append(float(tok))
    flush()
    return ''.join(out)


# BMa74 / BPa74 outlines (Norske tog's SVG), as in no_flirt.py.
BODY_UPPER = 'M1379 128.7H1374.4V123.2H1082.3V128.7H927.401V123.2H762.701V128.7H676.501L547.801 140.7H1.00078L0.800781 331.7L1295.5 333.5L1453.4 332.6C1453.4 332.6 1538.8 334.2 1578.7 338.5C1578.7 338.5 1544.1 152.4 1379.1 122.8V128.7H1379Z'
BODY_LOWER = 'M1281.5 333.7H0.800781V401.2H96.5008C101.101 401.2 102.801 403.6 102.801 403.6V409.6L104.801 411.6H1080.7C1080.7 411.6 1082.7 409.8 1085.6 407.4C1092.4 401.5 1104.4 391.5 1108.1 389.3C1126.5 378.6 1142.9 379 1142.8 378.4C1141.9 372.7 1146.5 373.4 1146.5 373.4C1146.5 373.4 1197.7 373.4 1203.2 373.4H1243.2C1243.2 373.4 1282.4 373.2 1290.5 373.2C1298.6 373.2 1294.7 379.6 1294.7 379.6C1294.7 379.6 1323.5 380.2 1327.2 382.6C1331 385.2 1354 395.9 1357.8 398.6C1360.4 400.5 1381.5 412.6 1384.4 414.3C1387.3 416 1388.9 415.9 1388.9 415.9C1388.9 415.9 1443.7 415.9 1447.1 415.9C1450.5 415.9 1451.6 414 1451.6 414C1451.6 414 1460.9 395.9 1461.7 394.1C1462.5 392.3 1464 392.6 1464 392.6C1471.7 391.1 1570.9 394.9 1572.3 394.6C1573.7 394.3 1575.6 387.2 1575.6 387.2H1565.2C1561.8 387.2 1562.4 384.6 1562.4 384.6C1564.8 378.4 1568.8 359.7 1569.5 355.7C1570.2 351.7 1574.1 352.3 1574.1 352.3H1580.8V345.5C1576.5 342.9 1572.8 337.3 1572.8 337.3C1463.9 330.5 1377.2 331.4 1377.2 331.4L1281.4 333.5L1281.5 333.7Z'
NOSE_BAND = 'M1574.9 338.4L1580.5 338.9C1580.5 338.9 1583.4 336 1584.1 335.6C1584.1 335.6 1584.4 304.3 1570.6 279.9L1560.5 276C1560.5 276 1543 238.9 1531 225.7C1519 212.5 1507.2 198.3 1501.8 192.7C1496.4 187.1 1473.4 166.9 1467.1 164.3C1467.1 164.3 1448.3 149.7 1446 148.2C1443.8 146.7 1413.1 127.8 1390.2 124.8C1390.2 124.8 1382.7 123.2 1381.6 123.3C1380.5 123.3 1378.2 122.9 1378.2 126.9V139.4C1378.2 139.4 1412.5 135.3 1455.6 158C1498.7 180.6 1528.8 226.6 1528.8 226.6C1528.8 226.6 1554.7 269 1562.4 291.1C1570.1 313.1 1573.7 321.1 1574.7 338.4H1574.9Z'
SEAM_OVERLAP = 'M0.8 325H1560V340H0.8Z'  # the two outlines meet at y 331-334 with a hairline gap; this strip closes it
HEADLIGHT = 'M1571.7 311.3C1571.7 311.3 1579.4 316.9 1580.8 319.7C1580.8 319.7 1582.5 328.5 1582.1 331.3C1582.1 331.3 1578.6 328.9 1575.3 328.1C1575.3 328.1 1574.2 318.2 1571.8 311.3H1571.7Z'
LOWER_SEAM = 'M1378.1 332.1C1378.1 332.1 1546 332.7 1580.7 339.2'
PLOUGH = 'M1493 393.2L1547.1 400.3C1547.1 400.3 1544 409.4 1553.6 419C1563.3 428.7 1572.2 434.1 1563.3 433.3C1558.1 432.8 1542.8 433.1 1530.5 433.3C1521.3 433.5 1513.8 433.8 1513.8 433.8L1455.1 408.9L1462.7 394.1C1462.7 394.1 1463.2 392.7 1465.9 392.5C1468.6 392.3 1492.9 393 1492.9 393L1493 393.2Z'
COUPLER = 'M1581.9 352.7L1602.1 354.8V385.2L1576.8 387.4H1565.4C1565.4 387.4 1562.8 387.2 1563.6 384.2C1564.5 381.2 1567.7 371.3 1568.7 365.4C1569.7 359.5 1570.7 355.1 1571 354.7C1571.3 354.3 1571.8 352.7 1575.2 352.7C1578.4 352.7 1581.8 352.7 1581.8 352.7Z'
BPA_DX = -1585.2
BPA_BODY = 'M1548.5 401.2V154.9H1494.9C1494.9 154.9 1489 154.9 1484 149.7C1479 144.5 1474.3 140 1474.3 140L1300 140L1300 401.2Z'

HIGH, LOW, TALL = (233.0, 304.3), (260.1, 331.4), (233.7, 331.2)
WINDOWS = [(58.4, 174.5, HIGH), (204.0, 320.1, LOW), (362.5, 478.6, LOW), (516.7, 632.8, LOW), (670.2, 786.3, TALL), (975.0, 1091.1, HIGH)]
DOOR_X, DOOR_W, DOOR_Y, DOOR_WIN_Y = 822.6, 116.1, (214.3, 396.0), (230.4, 331.2)
SEAM, CAB_JOINT = 185.9, 1377.9
ROOF_MODULE = (1302.0, 1377.9)
LOUVRES = [(604.0, 719.0, 145.0, 176.0), (1336.8, 1362.5, 142.4, 180.9)]
GRILLES = [(285, 360), (746, 822), (832, 906), (914, 982), (1027, 1064), (1110, 1180), (1190, 1227), (1251, 1302)]
GRILLE_Y = (145.0, 176.0)

d.gradient('vrgreen', ['#25c86b', '#0bb553', '#079a47'], stops=(0, 0.55, 1))
d.gradient('vrwhite', ['#f7f8f5', '#eef0ea', '#dfe2dc'], stops=(0, 0.55, 1))
d.gradient('module', ['#8f98a3', '#a9b0b9'])
VR_RED = '#c0444c'
CREAM = 'url(#vrwhite)'

# Speed lines (E px): rows, white share along the car, change lines.
PITCH, ROW0 = 9.45, 237.9
ROWS = [ROW0 + PITCH * k for k in range(-5, 18)]
THIN, THICK, TAPER, RAMP = 0.225, 0.75, 12.0, 100.0
B = {'b0': (1133.5, -0.60), 'b1': (943.0, -1.30), 'b2': (795.0, -0.78), 'b3': (535.0, -0.83), 'b4': (305.0, -0.82), 'b5': (88.0, -0.83)}


def bx(name, y):
    a, s = B[name]
    return a + s * (y - 280)


def white_share(y):
    """(x, share) points along a row, rear to front."""
    b0, b1, b2, b3, b4, b5 = (bx(n, y) for n in ('b0', 'b1', 'b2', 'b3', 'b4', 'b5'))
    return [(-40, 0), (b5, 0), (b5 + TAPER, THIN), (b4 - RAMP / 2, THIN), (b4 + RAMP / 2, THICK), (b3 - TAPER, THICK), (b3, 1), (b2, 1),
            (b2 + TAPER, THICK), (b1 - RAMP / 2, THICK), (b1 + RAMP / 2, THIN), (b0 - TAPER, THIN), (b0, 0), (1400, 0)]


def speed_lines():
    """One band per row; the first and last rows reach the seam and the underside, so the white middle is closed."""
    lo, hi = SEAM, EB + 6
    for i, yc in enumerate(ROWS):
        up = (yc - lo) if i == 0 else PITCH / 2
        dn = (hi - yc) if i == len(ROWS) - 1 else PITCH / 2
        pts = white_share(yc)
        top = ' '.join(f'{ex(x):.1f},{ey(yc - w * up):.1f}' for x, w in pts)
        bot = ' '.join(f'{ex(x):.1f},{ey(yc + w * dn):.1f}' for x, w in reversed(pts))
        d.paint(f'<polygon points="{top} {bot}" fill="{CREAM}"/>', VR)
    # The all-white middle as one shape (between b3 and b2), so no hairlines show between the rows there.
    d.paint(f'<polygon points="{ex(bx("b3", lo)):.1f},{ey(lo):.1f} {ex(bx("b2", lo)):.1f},{ey(lo):.1f} {ex(bx("b2", hi)):.1f},{ey(hi):.1f} {ex(bx("b3", hi)):.1f},{ey(hi):.1f}" fill="{CREAM}"/>', VR)


def door():
    x, w = ex(DOOR_X), DOOR_W * K
    d.paint(f'<rect x="{x:.1f}" y="{ey(DOOR_Y[0]):.1f}" width="{w:.1f}" height="{ey(DOOR_Y[1]) - ey(DOOR_Y[0]):.1f}" rx="3" fill="url(#vrgreen)"/>', VR)
    d.door(x, w, f(DOOR_Y[0]), f(DOOR_Y[1]))
    d.add(f'<line x1="{x + w / 2:.1f}" y1="{ey(DOOR_Y[0]) + 1:.1f}" x2="{x + w / 2:.1f}" y2="{ey(DOOR_Y[1]) - 1:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
    for l, r in ((0.132, 0.372), (0.627, 0.866)):
        d.add(f'<rect x="{x + l * w:.1f}" y="{ey(DOOR_WIN_Y[0]):.1f}" width="{(r - l) * w:.1f}" height="{ey(DOOR_WIN_Y[1]) - ey(DOOR_WIN_Y[0]):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')


def rect(x0, x1, y0, y1, **attrs):
    a = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return f'<rect x="{ex(x0):.1f}" y="{ey(y0):.1f}" width="{(x1 - x0) * K:.1f}" height="{(y1 - y0) * K:.1f}" {a}/>'


def louvre(x0, x1, y0, y1, n=7):
    d.add(rect(x0, x1, y0, y1, rx=1.5, fill='#7d858f'))
    for i in range(n):
        yy = y0 + (i + 0.5) * (y1 - y0) / n
        d.add(f'<line x1="{ex(x0) + 1.5:.1f}" y1="{ey(yy):.1f}" x2="{ex(x1) - 1.5:.1f}" y2="{ey(yy):.1f}" stroke="#3a4048" stroke-width="1"/>')


# Bogies first, so the skirt hides the wheel tops (lib.py's style, to scale, as no_flirt.py).
d.bogie(ex(-17.6), axle_m=2.75, wheel_m=0.92, top=ey(401.2), wc=ey(413.8))
d.bogie(ex(1229.5), axle_m=2.5, wheel_m=0.92, top=ey(373), wc=ey(413.8))

# Car 2, its front end: green, white lines starting from tips on b5's slope (Segerstad).
d.clip('c2', epath(BPA_BODY, BPA_DX))
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{ey(SEAM) - ROOF + 10:.1f}" fill="url(#roof)"/>')
d.add(f'<line x1="{d.VB_X - 10:.1f}" y1="{ey(SEAM):.1f}" x2="{S:.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>', 'plain')
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{ey(SEAM):.1f}" width="{S - d.VB_X + 10:.1f}" height="{BASE - ey(SEAM) + 10:.1f}" fill="url(#vrgreen)"/>', VR)
for yc in ROWS:
    tip = S - 0.83 * (yc - SEAM) * K  # drawing x of the tip, measured back from car 2's end
    h = THIN * PITCH * K / 2
    d.paint(f'<polygon points="{d.VB_X - 10:.1f},{ey(yc) - h:.1f} {tip - TAPER * K:.1f},{ey(yc) - h:.1f} {tip:.1f},{ey(yc):.1f} {tip - TAPER * K:.1f},{ey(yc) + h:.1f} {d.VB_X - 10:.1f},{ey(yc) + h:.1f}" fill="{CREAM}"/>', VR)
d.end()

# Gangway: bellows, plate, rounded cover (as no_flirt.py).
g0, g1 = S, REAR
d.add(f'<rect x="{g0}" y="{ey(187.6):.1f}" width="{g1 - g0}" height="{ey(400.7) - ey(187.6):.1f}" fill="#2b3037"/>')
for i in range(1, 5):
    d.add(f'<line x1="{g0 + i * (g1 - g0) / 5:.1f}" y1="{ey(190.9):.1f}" x2="{g0 + i * (g1 - g0) / 5:.1f}" y2="{ey(400.4):.1f}" stroke="#41474f" stroke-width="1.5"/>')
d.add(f'<path d="M{g0},{ey(174.4):.1f} L{g1},{ey(176.8):.1f} V{ey(182.7):.1f} L{g0},{ey(181.7):.1f} Z" fill="#3a4048"/>')
d.add(f'<path d="M{g0},{ey(154.6):.1f} A{(g1 - g0) / 2:.1f},{ey(154.6) - ey(135.5):.1f} 0 0 1 {g1},{ey(154.6):.1f} Z" fill="#3a4048"/>')

# Cab car.
d.defs['c1'] = f'<clipPath id="c1"><path d="{epath(BODY_UPPER)}"/><path d="{epath(BODY_LOWER)}"/><path d="{epath(NOSE_BAND)}"/><path d="{epath(SEAM_OVERLAP)}"/></clipPath>'
d.group('c1')
d.add(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{TIP - REAR + 14}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{ex(CAB_JOINT) - REAR + 2:.1f}" height="{ey(SEAM) - ROOF + 10:.1f}" fill="url(#roof)"/>')
# VR: green side, the cab module green to the top, speed lines.
d.paint(f'<rect x="{REAR - 2}" y="{ey(SEAM):.1f}" width="{TIP - REAR + 14}" height="{BASE - ey(SEAM) + 10:.1f}" fill="url(#vrgreen)"/>', VR)
d.paint(f'<rect x="{ex(CAB_JOINT):.1f}" y="{ROOF - 10}" width="{TIP - ex(CAB_JOINT) + 12:.1f}" height="{d.H + 20}" fill="url(#vrgreen)"/>', VR)
speed_lines()
d.add(f'<line x1="{REAR}" y1="{ey(SEAM):.1f}" x2="{ex(CAB_JOINT):.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>', 'plain')
d.add(f'<line x1="{ex(CAB_JOINT):.1f}" y1="{ey(123):.1f}" x2="{ex(CAB_JOINT):.1f}" y2="{ey(409):.1f}" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
d.add(f'<path d="{epath(LOWER_SEAM)}" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
# Roof: grey module behind the cab, louvres, grille panels (red on the VR trains).
d.add(rect(ROOF_MODULE[0], ROOF_MODULE[1], 120.0, SEAM, fill='url(#module)'))
d.add(f'<line x1="{ex(ROOF_MODULE[0]):.1f}" y1="{ey(122):.1f}" x2="{ex(ROOF_MODULE[0]):.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.2" stroke-width="1"/>')
for x0, x1, y0, y1 in LOUVRES:
    louvre(x0, x1, y0, y1)
for x0, x1 in GRILLES:
    d.add(rect(x0 + 2, x1 - 2, *GRILLE_Y, rx=1.5, fill='#a3aab2', stroke='#8a929b', stroke_width=0.8), 'plain')
    d.paint(rect(x0 + 2, x1 - 2, *GRILLE_Y, rx=1.5, fill=VR_RED), VR)
for x0, x1, (t, b) in WINDOWS:
    d.windows(ex(x0), ex(x1), 1, f(t), f(b))
door()
# Cab side: window, hatch with two grilles, camera box.
d.add(rect(1389, 1434, 232, 307, rx=5, fill='#0b0d10'))
d.add(rect(1392.5, 1430.5, 235.5, 303.5, rx=4, fill='url(#glass)'))
d.add(rect(1256, 1320, 255, 328, rx=6, fill='none', stroke='#000', stroke_opacity=0.35, stroke_width=1.2))
for y0, y1 in ((267, 282), (300, 314)):
    d.add(rect(1275, 1303, y0, y1, rx=1.5, fill='#1d2228'))
d.add(rect(1299, 1322, 218, 237, rx=2, fill='#1d2228'))
d.add(f'<path d="{epath(NOSE_BAND)}" fill="#14181e"/>')
d.add(f'<path d="{epath(HEADLIGHT)}" fill="#f7f9fb" stroke="#4b4f55" stroke-width="0.8"/>')
d.end()

d.add(f'<rect x="{ex(DOOR_X):.1f}" y="{ey(406.4):.1f}" width="{DOOR_W * K:.1f}" height="{(416.1 - 406.4) * K:.1f}" fill="#3a4450"/>')
d.add(f'<path d="{epath(PLOUGH)}" fill="#3b4148"/>')
d.add(f'<path d="{epath(COUPLER)}" fill="#2a2f36"/>')

COMMENT = '// Sweden X74 (Stadler FLIRT Nordic, cab car), side view to scale. Generated by scripts/trains/x74.py (sources and measurements there); docs/TRAIN_ART.md.'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'apps', 'web', 'src', 'components', 'trains', 'X74.tsx')
if __name__ == '__main__':
    main(d, 'X74Side', COMMENT, OUT)
