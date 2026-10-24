"""Norway Type 76 (Stadler FLIRT bimodal, 6 cars, run by SJ Nord). docs/TRAIN_ART.md; x3.py is the worked example.

What it is: a bimodal (electric + diesel) FLIRT, BMa + BPa + BC + XDe + BPb + BMb. Car 4 (XDe) is a power car of four
480 kW diesel generator packs with no seats or doors; 112.7 m, 14 sets (76-01..14) from 2020-22, owned by Norske tog,
run by SJ Norge (brand SJ Nord) on Trønderbanen (R70), Rørosbanen (R60) and Meråkerbanen (R71). no.wikipedia
"Type 76 (motorvognsett)", retrieved 2026-10-22.

Drawn: the BMa cab car (cab facing right) and the end of BPa; liveries `sj-nord` and unpainted.

Sources (retrieved 2026-10-22):
- Norske tog side elevations: https://www.norsketog.no/uploads/trains/filled/motor-coach/Type76/type76_BMa76.svg and
  type76_BPa76.svg (page https://www.norsketog.no/tog/motorvognsett/type-76); the same for Type 74
  (.../Type74/type74_BMa74.svg, type74_BPa74.svg), whose scale is checked in no_flirt.py (74.4 px/m).
- Photos (features and colours only, none is side-on to the cab car): Norske tog
  https://www.norsketog.no/imager/images/Tog-i-landskap/3118/type-76-tronderbanen-sj-02_e1c911f2f3d0fd466fe982bf5a56cab5.jpg;
  jarnvag.net https://www.jarnvag.net/images/bild/banguide/Trondheim250617.jpg (2025-06); jernbane.net topic
  https://jernbane.net/bo/subpage.php?s=3&t=16491 (350 px previews, 2021-2026), incl. side-on BC 76314 (2025-10-24).

Measurements. The BMa76 elevation is not drawn at one scale: vertically 72.2 px/m (rail y 449 to cab roof 132.7 =
4.38 m, as Type 74), horizontally 68.1 px/m (the five passenger cars then add up to 105.0 m + the 7.2 m longer train;
at 72.2 they'd be 99 m). Read at 68.1 px/m from its nose tip (x 1457.1), every door, window and the car end of BMa76
falls within 0.1 m of BMa74's: front door edge 8.72 m (74: 8.67), window ahead of it 6.66 m (6.63), rear door 16.94 m
(16.92), car length 21.36 m (21.28); the window heights from the rail match too (high window top 2.90 m, both). So the
body, doors, windows, nose, bogies and gangway are drawn from the BMa74 elevation exactly as in no_flirt.py (numbers
there). What differs on BMa76, converted at 68.1 px/m from the nose and 72.2 px/m from the rail:
- cab side window: a rounded rectangle, frame x 1268.7-1315.8, y 235.5-312.3, glass 1272.6-1312.1 x 239.4-308.6
  (BMa74 has a D-shaped window); photos show the same narrow window.
- roof: covers 971.5-1254.8 and 661.6-821.3 (y 133.2), the roof stepping down from 578.0 to 453.2 (y 138.5 to
  150.1), grilles as in ROOF76_GRILLES.
- BPa76 end: same roof step as BPa74 (within 0.06 m). Its pantograph stands on that step: base plate x 1138.4-1191.6
  at y 159.9 and two insulators (0.4-0.6 m from the car end). The elevation shows it raised 1.25 m above the roof,
  which is above the picture's frame; the sets run mostly on diesel, and no source shows the lowered pantograph's
  shape, so only the base and insulators are drawn.
Livery `sj-nord` (current: every Type 76 photo from 2025-26; earlier sets ran in Norske tog's dark grey with orange
door frames, 2021-23). Measured on two near-side-on Flickr photos, retrieved 2026-10-22, each rectified onto the
elevation with a homography fitted to door-window, window and cab-window corners (residuals 2-5 px = 0.03-0.07 m):
  - 76107 at Trondheim, 2025-06-16, https://www.flickr.com/photos/123594177@N08/54778110760 (4096 px; mirrored, cab right)
  - 76503 at Trondheim, 2026-04-01, https://www.flickr.com/photos/buraeepp/55188047067 (2048 px; BMb, same front section)
  Both show what Garner's photos show (via the coordinator): navy cab end, dark grey body, a pink stripe slanting from
  the roof edge down and forward, pink door frames.
- the stripe is straight on the flat of the side (rms 0.2 px off a line in both photos); it bends only where the roof
  and the lower body curve away from the plane. After removing the photos' residual shear (door edges lean 0.05-0.07),
  its rear edge is x = 1151.3 + 0.958 (y - 280) (the two photos agree to 0.017 in slope and 1 px in position), pink
  20.1 px wide, then a light grey band 9.2 px wide on its front edge; from the roof edge (y 178.5) down until the body
  ends (it meets the bogie arch at about x 1240, y 373).
- the cab end in front of it is navy, its roof too (the roof boundary continues the line); behind it the body is dark
  grey and the roof grey. Colours from the photos (overcast, so dull) and Garner's #2b3f7a: navy #2d4381, grey #3b4247,
  pink #ee5870, band #c3c7cf.
- door frames: pink, 10.5 px wide up both sides of the door leaf and over its top (y 203.5-214.5), sides ending at y
  389.3; door leaves in body grey.
Overlays (scratchpad): every edge coincides on the elevation; on both rectified photos the stripe, door frames, windows
and roof colour edge coincide (the noses differ: the photos see the front in perspective).
Bogies: lib.py's bogie() (wheels behind a side frame), as both photos show them; drawn before the body so the skirt
hides the wheel tops, the frame from the underside (y 373 in the arch under the cab).
Not drawn: logo, numbers, lettering.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Drawing, main  # noqa: E402

PXM = 74.4  # BMa74 elevation px per metre
EN, ER, EB = 1584.1, 128.7, 411.6  # BMa74: nose tip x, roof line y, body underside y
SJ = 'sj-nord'
d = Drawing(car_m=(EN - 0.8) / PXM, body_m=(EB - ER) / PXM, gangway_m=38.2 / PXM, liveries=[SJ])
M, ROOF, BASE, TIP, REAR, S = d.M, d.ROOF, d.BASE, d.TIP, d.REAR, d.SECOND_END
K = M / PXM


def ex(px):
    return TIP - (EN - px) * K


def ey(py):
    return ROOF + (py - ER) * K


def f(py):
    return (py - ER) / (EB - ER)


# BMa76 elevation px -> BMa74 elevation px (68.1 px/m from the nose tip at 1457.1; 72.2 px/m from the rail at 449).
def e76x(px):
    return EN - (1457.1 - px) / 68.1 * PXM


def e76y(py):
    return 449 - (449 - py) / 72.2 * PXM


# BPa76 px -> BPa74 px (car ends 1201.1 / 1548.5).
def b76x(px):
    return 1548.5 - (1201.1 - px) / 68.1 * PXM


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


# BMa74 outlines (Norske tog's SVG), with the roof of BMa76 in place of BMa74's.
c76 = e76y(133.2)
ROOF76 = (
    f'M1379 128.7H{e76x(1254.7):.1f}V{c76:.1f}H{e76x(971.5):.1f}V128.7H{e76x(821.3):.1f}V{c76:.1f}H{e76x(661.6):.1f}V128.7'
    f'H{e76x(578.0):.1f}L{e76x(453.2):.1f} {e76y(150.1):.1f}H1.0'
)
BODY_UPPER = ROOF76 + 'L0.800781 331.7L1295.5 333.5L1453.4 332.6C1453.4 332.6 1538.8 334.2 1578.7 338.5C1578.7 338.5 1544.1 152.4 1379.1 122.8V128.7H1379Z'
BODY_LOWER = 'M1281.5 333.7H0.800781V401.2H96.5008C101.101 401.2 102.801 403.6 102.801 403.6V409.6L104.801 411.6H1080.7C1080.7 411.6 1082.7 409.8 1085.6 407.4C1092.4 401.5 1104.4 391.5 1108.1 389.3C1126.5 378.6 1142.9 379 1142.8 378.4C1141.9 372.7 1146.5 373.4 1146.5 373.4C1146.5 373.4 1197.7 373.4 1203.2 373.4H1243.2C1243.2 373.4 1282.4 373.2 1290.5 373.2C1298.6 373.2 1294.7 379.6 1294.7 379.6C1294.7 379.6 1323.5 380.2 1327.2 382.6C1331 385.2 1354 395.9 1357.8 398.6C1360.4 400.5 1381.5 412.6 1384.4 414.3C1387.3 416 1388.9 415.9 1388.9 415.9C1388.9 415.9 1443.7 415.9 1447.1 415.9C1450.5 415.9 1451.6 414 1451.6 414C1451.6 414 1460.9 395.9 1461.7 394.1C1462.5 392.3 1464 392.6 1464 392.6C1471.7 391.1 1570.9 394.9 1572.3 394.6C1573.7 394.3 1575.6 387.2 1575.6 387.2H1565.2C1561.8 387.2 1562.4 384.6 1562.4 384.6C1564.8 378.4 1568.8 359.7 1569.5 355.7C1570.2 351.7 1574.1 352.3 1574.1 352.3H1580.8V345.5C1576.5 342.9 1572.8 337.3 1572.8 337.3C1463.9 330.5 1377.2 331.4 1377.2 331.4L1281.4 333.5L1281.5 333.7Z'
NOSE_BAND = 'M1574.9 338.4L1580.5 338.9C1580.5 338.9 1583.4 336 1584.1 335.6C1584.1 335.6 1584.4 304.3 1570.6 279.9L1560.5 276C1560.5 276 1543 238.9 1531 225.7C1519 212.5 1507.2 198.3 1501.8 192.7C1496.4 187.1 1473.4 166.9 1467.1 164.3C1467.1 164.3 1448.3 149.7 1446 148.2C1443.8 146.7 1413.1 127.8 1390.2 124.8C1390.2 124.8 1382.7 123.2 1381.6 123.3C1380.5 123.3 1378.2 122.9 1378.2 126.9V139.4C1378.2 139.4 1412.5 135.3 1455.6 158C1498.7 180.6 1528.8 226.6 1528.8 226.6C1528.8 226.6 1554.7 269 1562.4 291.1C1570.1 313.1 1573.7 321.1 1574.7 338.4H1574.9Z'
SEAM_OVERLAP = 'M0.8 325H1560V340H0.8Z'  # the two outlines meet at y 331-334 with a hairline gap; this strip closes it
HEADLIGHT = 'M1571.7 311.3C1571.7 311.3 1579.4 316.9 1580.8 319.7C1580.8 319.7 1582.5 328.5 1582.1 331.3C1582.1 331.3 1578.6 328.9 1575.3 328.1C1575.3 328.1 1574.2 318.2 1571.8 311.3H1571.7Z'
LOWER_SEAM = 'M1378.1 332.1C1378.1 332.1 1546 332.7 1580.7 339.2'
PLOUGH = 'M1493 393.2L1547.1 400.3C1547.1 400.3 1544 409.4 1553.6 419C1563.3 428.7 1572.2 434.1 1563.3 433.3C1558.1 432.8 1542.8 433.1 1530.5 433.3C1521.3 433.5 1513.8 433.8 1513.8 433.8L1455.1 408.9L1462.7 394.1C1462.7 394.1 1463.2 392.7 1465.9 392.5C1468.6 392.3 1492.9 393 1492.9 393L1493 393.2Z'
COUPLER = 'M1581.9 352.7L1602.1 354.8V385.2L1576.8 387.4H1565.4C1565.4 387.4 1562.8 387.2 1563.6 384.2C1564.5 381.2 1567.7 371.3 1568.7 365.4C1569.7 359.5 1570.7 355.1 1571 354.7C1571.3 354.3 1571.8 352.7 1575.2 352.7C1578.4 352.7 1581.8 352.7 1581.8 352.7Z'
BPA_DX = -1585.2  # BPa74 x 1548.2 (gangway) = BMa74 x -37.0
BPA_BODY = 'M1548.5 401.2V154.9H1494.9C1494.9 154.9 1489 154.9 1484 149.7C1479 144.5 1474.3 140 1474.3 140L1300 140L1300 401.2Z'
ROOF76_GRILLES = [(1217.6, 1242.6, 151.7, 189.1), (1164.4, 1199.7, 160.4, 178.7), (1034.6, 1120.5, 152.1, 189.5), (941.1, 1027.0, 152.1, 189.5),
                  (724.3, 774.1, 152.1, 189.5), (606.9, 656.7, 152.1, 189.5), (270.0, 355.9, 152.1, 189.5)]

HIGH, LOW, TALL = (233.0, 304.3), (260.1, 331.4), (233.7, 331.2)
WINDOWS = [(58.4, 174.5, HIGH), (362.5, 478.6, TALL), (516.7, 632.8, LOW), (670.2, 786.3, TALL), (975.0, 1091.1, HIGH)]
DOORS = [209.3, 822.6]
DOOR_W, DOOR_Y, DOOR_WIN_Y = 116.1, (214.3, 396.0), (230.4, 331.2)
SEAM, CAB_JOINT = 185.9, 1377.9


# SJ Nord (measured on two rectified photos, see the docstring).
d.gradient('sjblue', ['#3a5394', '#2d4381', '#23356b'], stops=(0, 0.55, 1))
d.gradient('sjgrey', ['#4d555b', '#3b4247', '#2c3236'], stops=(0, 0.55, 1))
d.gradient('sjroof', ['#7d848c', '#999fa6'])
d.gradient('sjroofblue', ['#4a6099', '#3a508a'])
SJ_PINK, SJ_BAND = '#ee5870', '#c3c7cf'
SJ_PAINT_TOP = 178.5  # roof colour down to here


def sj_rear(y):
    """The stripe's rear edge (elevation px): x = 1151.3 + 0.958 (y - 280)."""
    return 1151.3 + 0.958 * (y - 280)


SJ_PINK_W, SJ_BAND_W = 20.1, 9.2  # px, measured horizontally
FRAME_W, FRAME_TOP, FRAME_BOTTOM = 10.5, 203.5, 389.3


def door_frame(x0):
    """SJ Nord's pink frame up the door's sides and over its top, 10.5 px wide, sides ending at y 389.3."""
    l, r, t, b, rr = x0 - FRAME_W, x0 + DOOR_W + FRAME_W, FRAME_TOP, FRAME_BOTTOM, 8
    pts = (f'M{ex(l):.1f},{ey(b):.1f} V{ey(t + rr):.1f} Q{ex(l):.1f},{ey(t):.1f} {ex(l + rr):.1f},{ey(t):.1f} H{ex(r - rr):.1f} '
           f'Q{ex(r):.1f},{ey(t):.1f} {ex(r):.1f},{ey(t + rr):.1f} V{ey(b):.1f} H{ex(x0 + DOOR_W):.1f} V{ey(DOOR_Y[0]):.1f} H{ex(x0):.1f} V{ey(b):.1f} Z')
    d.paint(f'<path d="{pts}" fill="{SJ_PINK}"/>', SJ)


def door(x0):
    x, w = ex(x0), DOOR_W * K
    d.door(x, w, f(DOOR_Y[0]), f(DOOR_Y[1]))
    d.add(f'<line x1="{x + w / 2:.1f}" y1="{ey(DOOR_Y[0]) + 1:.1f}" x2="{x + w / 2:.1f}" y2="{ey(DOOR_Y[1]) - 1:.1f}" stroke="#8d949c" stroke-width="1.2"/>')
    for l, r in ((0.132, 0.372), (0.627, 0.866)):
        d.add(f'<rect x="{x + l * w:.1f}" y="{ey(DOOR_WIN_Y[0]):.1f}" width="{(r - l) * w:.1f}" height="{ey(DOOR_WIN_Y[1]) - ey(DOOR_WIN_Y[0]):.1f}" rx="4" fill="url(#glass)" stroke="#0b0d10" stroke-width="2"/>')


# Bogies first, so the body skirt hides the wheel tops as on the train (lib.py's style: wheels behind a side frame), to scale: wheel centres at elevation y 413.8; the frame starts
# at the body's underside there (401.2 under the gangway, 373 in the arch under the cab). Jacobs bogie axles 2.75 m,
# motor bogie 2.5 m, wheels 0.92 m.
d.bogie(ex(-17.6), axle_m=2.75, wheel_m=0.92, top=ey(401.2), wc=ey(413.8))
d.bogie(ex(1229.5), axle_m=2.5, wheel_m=0.92, top=ey(373), wc=ey(413.8))

# BPa end: roof step, pantograph base plate and insulators (BPa76, converted).
d.clip('c2', epath(BPA_BODY, BPA_DX))
d.group('c2')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{d.H + 20}" fill="url(#body)"/>')
d.add(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{ey(SEAM) - ROOF + 10:.1f}" fill="url(#roof)"/>')
d.add(f'<line x1="{d.VB_X - 10:.1f}" y1="{ey(SEAM):.1f}" x2="{S:.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>', 'plain')
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{d.H + 20}" fill="url(#sjgrey)"/>', SJ)
d.paint(f'<rect x="{d.VB_X - 10:.1f}" y="{ROOF - 10}" width="{S - d.VB_X + 10:.1f}" height="{ey(SJ_PAINT_TOP) - ROOF + 10:.1f}" fill="url(#sjroof)"/>', SJ)
d.end()
base_y = e76y(159.9)
d.add(f'<rect x="{ex(b76x(1138.4) + BPA_DX):.1f}" y="{ey(base_y) - 1.5:.1f}" width="{(b76x(1191.6) - b76x(1138.4)) * K:.1f}" height="{ey(154.9) - ey(base_y) + 1.5:.1f}" rx="1" fill="#59616a"/>')
for (x0, y0), (x1, y1) in (((1175.5, 159.9), (1170.3, 150.7)), ((1163.0, 151.1), (1158.0, 159.9))):
    d.add(f'<line x1="{ex(b76x(x0) + BPA_DX):.1f}" y1="{ey(e76y(y0)):.1f}" x2="{ex(b76x(x1) + BPA_DX):.1f}" y2="{ey(e76y(y1)):.1f}" stroke="#59616a" stroke-width="2.2" stroke-linecap="round"/>')
d.add(f'<circle cx="{ex(b76x(1166.7) + BPA_DX):.1f}" cy="{ey(e76y(151.7)):.1f}" r="{3.8 / 68.1 * M:.1f}" fill="#59616a"/>')

# Gangway: bellows, the plate over it and its rounded cover (as no_flirt.py).
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
d.add(f'<line x1="{REAR}" y1="{ey(SEAM):.1f}" x2="{ex(CAB_JOINT):.1f}" y2="{ey(SEAM):.1f}" stroke="#000" stroke-opacity="0.13" stroke-width="1.2"/>', 'plain')
# SJ Nord: grey body and roof; the cab end navy (its roof too) in front of a straight pink stripe with a light band
# on its front edge, from the roof edge down to the sill (clipped by the body, so it stops at the bogie arch).
yt, yb = SJ_PAINT_TOP, 430.0
d.paint(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{TIP - REAR + 14}" height="{d.H + 20}" fill="url(#sjgrey)"/>', SJ)
d.paint(f'<rect x="{REAR - 2}" y="{ROOF - 10}" width="{TIP - REAR + 14}" height="{ey(yt) - ROOF + 10:.1f}" fill="url(#sjroof)"/>', SJ)
bf = lambda y: sj_rear(y) + SJ_PINK_W + SJ_BAND_W  # noqa: E731
d.paint(f'<path d="M{ex(bf(100)):.1f},{ey(100):.1f} L{ex(bf(yb)):.1f},{ey(yb):.1f} H{TIP + 12} V{ey(100):.1f} Z" fill="url(#sjblue)"/>', SJ)
d.paint(f'<path d="M{ex(bf(100)):.1f},{ey(100):.1f} L{ex(bf(yt)):.1f},{ey(yt):.1f} H{ex(CAB_JOINT):.1f} V{ey(100):.1f} Z" fill="url(#sjroofblue)"/>', SJ)
for x0, w, colour in ((0, SJ_PINK_W, SJ_PINK), (SJ_PINK_W, SJ_BAND_W, SJ_BAND)):
    a0, a1 = sj_rear(yt) + x0, sj_rear(yb) + x0
    d.paint(f'<path d="M{ex(a0):.1f},{ey(yt):.1f} L{ex(a1):.1f},{ey(yb):.1f} H{ex(a1 + w):.1f} L{ex(a0 + w):.1f},{ey(yt):.1f} Z" fill="{colour}"/>', SJ)
for x0 in DOORS:
    door_frame(x0)
d.add(f'<line x1="{ex(CAB_JOINT):.1f}" y1="{ey(123):.1f}" x2="{ex(CAB_JOINT):.1f}" y2="{ey(409):.1f}" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
d.add(f'<path d="{epath(LOWER_SEAM)}" fill="none" stroke="#000" stroke-opacity="0.18" stroke-width="1.2"/>')
for x0, x1, y0, y1 in ROOF76_GRILLES:
    X0, X1, Y0, Y1 = e76x(x0), e76x(x1), e76y(y0), e76y(y1)
    d.add(f'<rect x="{ex(X0):.1f}" y="{ey(Y0):.1f}" width="{(X1 - X0) * K:.1f}" height="{(Y1 - Y0) * K:.1f}" rx="1.5" fill="#a3aab2" stroke="#8a929b" stroke-width="0.8"/>')
for x0, x1, (t, b) in WINDOWS:
    d.windows(ex(x0), ex(x1), 1, f(t), f(b))
for x0 in DOORS:
    door(x0)
d.add(f'<path d="{epath(NOSE_BAND)}" fill="#14181e"/>')
fx0, fx1, fy0, fy1 = e76x(1268.7), e76x(1315.8), e76y(235.5), e76y(312.3)
gx0, gx1, gy0, gy1 = e76x(1272.6), e76x(1312.1), e76y(239.4), e76y(308.6)
d.add(f'<rect x="{ex(fx0):.1f}" y="{ey(fy0):.1f}" width="{(fx1 - fx0) * K:.1f}" height="{(fy1 - fy0) * K:.1f}" rx="5" fill="#0b0d10"/>')
d.add(f'<rect x="{ex(gx0):.1f}" y="{ey(gy0):.1f}" width="{(gx1 - gx0) * K:.1f}" height="{(gy1 - gy0) * K:.1f}" rx="4" fill="url(#glass)"/>')
d.add(f'<path d="{epath(HEADLIGHT)}" fill="#f7f9fb" stroke="#4b4f55" stroke-width="0.8"/>')
d.end()

for x0 in DOORS:
    d.add(f'<rect x="{ex(x0):.1f}" y="{ey(406.4):.1f}" width="{DOOR_W * K:.1f}" height="{(416.1 - 406.4) * K:.1f}" fill="#3a4450"/>')
d.add(f'<path d="{epath(PLOUGH)}" fill="#3b4148"/>')
d.add(f'<path d="{epath(COUPLER)}" fill="#2a2f36"/>')

if __name__ == '__main__':
    main(d)
